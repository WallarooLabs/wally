#!/usr/bin/env python3.5

import asyncio
import click
import math
import sys
import time

from functions import mq_parse
import functions.fs as fs
from functions import state



THROUGHPUT_IN = 'throughput_in'
THROUGHPUT_OUT = 'throughput_out'
LATENCY_COUNT = 'latency_count'
LATENCY_TIME = 'latency_time'

class UDPMessageQueue(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        splat = mq_parse.decode(data).split(':')
        verb = splat[0]
        msg = splat[1] if len(splat) > 1 else ''

        if verb == 'PUT':
            # stamp event with current timestamp on queue insert
            QUEUE.put_nowait((time.time(), msg))
            # Measure throughput
            state.add(int(time.time()), 1, THROUGHPUT_IN)
            self.transport.sendto(
                    mq_parse.encode('PUT {} bytes'.format(len(msg))),
                    addr)
        elif verb == 'GET':
            try:
                t0, msg = QUEUE.get_nowait()
                self.transport.sendto(mq_parse.encode(msg),
                                      addr)
                # Compute time between when event was inserted
                # and when it was consumed by a remote client
                dt = time.time()-t0
                # Measure throughput
                state.add(int(time.time()), 1, THROUGHPUT_OUT)
                # Log latency to file
                # Add latency to histogram
                state.add('{:.09f} s'.format(10**round(math.log(dt,10))),
                          dt, LATENCY_TIME)
                state.add('{:.09f} s'.format(10**round(math.log(dt,10))),
                          1, LATENCY_COUNT)
            except asyncio.queues.QueueEmpty:
                self.transport.sendto(mq_parse.encode(''),
                                      addr)
        elif verb == 'SIZE':
            self.transport.sendto(
                mq_parse.encode('{}'.format(QUEUE.qsize())),
                addr)

    def connection_lost(self, exc):
        self.transport = None


STAT_TIME_BOUNDARY = time.time()
def process_statistics(call_later, period):
    global STAT_TIME_BOUNDARY
    t0 = STAT_TIME_BOUNDARY
    STAT_TIME_BOUNDARY = time.time()
    latency_time = state.pop(LATENCY_TIME, None)
    latency_count = state.pop(LATENCY_COUNT, None)
    throughput_in = state.pop(THROUGHPUT_IN, None)
    throughput_out = state.pop(THROUGHPUT_OUT, None)

    emit_statistics(t0, STAT_TIME_BOUNDARY,
                    ('latency_time', latency_time),
                    ('latency_count', latency_count),
                    ('throughput_in', throughput_in),
                    ('throughput_out', throughput_out))
    call_later(period, process_statistics, call_later, period)


def emit_statistics(t0, t1, *stats):
    for name, stat in stats:
        LOGGER.info("({}, {}) {}: {}".format(t0, t1, name, stat))


@click.command()
@click.option('--address', default='127.0.0.1:10000',
              help='Address to listen on')
@click.option('--console-log', is_flag=True, default=False,
              help='Log output to stdout.')
@click.option('--file-log', is_flag=True, default=False,
              help='Log output to file.')
@click.option('--stats-period', default=60,
              help='The period over which stats are measured.')
def start(address, console_log, file_log, stats_period):
    # Parse address string to host and port str:int pair
    host, port = [f(x) for f,x in
                  zip((str, int), address.split(':'))]

    # Create global queue object
    global QUEUE
    QUEUE = asyncio.Queue()

    # Create a global logger
    global LOGGER
    LOGGER = fs.get_logger('logs/{}.{}'.format('MQ',
                                               '{}-{}'.format(host, port)),
                           stream_out=console_log,
                           file_out=file_log)
    LOGGER.info('Starting Message Queue...')
    LOGGER.info('Address: %s', (host, port))

    # Create the main event loop object
    loop = asyncio.get_event_loop()
    # One protocol instance will be created to serve all client requests
    listen = loop.create_datagram_endpoint(
        UDPMessageQueue, local_addr=(host, port))
    transport, protocol = loop.run_until_complete(listen)

    # Create the call_later partial function
    call_later = loop.call_later
    # Start the listener event loop and run until SIGINT
    try:
        call_later(stats_period, process_statistics, call_later, stats_period)
        loop.run_forever()
    except KeyboardInterrupt:
        LOGGER.info("Shutting down")
        qsize = QUEUE.qsize()
        LOGGER.info("Queue size: {}".format(qsize))
        LOGGER.info("Latency_count: {}".format(
            state.get_attribute(LATENCY_COUNT, None)))
        LOGGER.info("Latency_time: {}".format(
            state.get_attribute(LATENCY_TIME, None)))
        pass


    transport.close()
    loop.close()


if __name__ == '__main__':
    start()
