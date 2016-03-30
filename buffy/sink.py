#!/usr/bin/env python3

"""sink listens on a specified address and port and emits
whatever it receives to console.
In addition, sink computes latencies using the value in FeedEpoch
in the incoming json message of the format
'{"msg": <msg>, "FeedEpoch": <epoch>}'.
"""


import asyncio
import click
import datetime
import json
import math
import requests
import time

import functions.fs as fs
from functions import state
from functions.vuid import get_vuid


# Generate a unique node/vertex id
VUID = None


THROUGHPUT_IN = 'throughput_in'
THROUGHPUT_OUT = 'throughput_out'
LATENCY_COUNT = 'latency_count'
LATENCY_TIME = 'latency_time'
STAT_TIME_BOUNDARY = time.time()


def process_statistics(call_later, period):
    global STAT_TIME_BOUNDARY
    t0 = STAT_TIME_BOUNDARY
    STAT_TIME_BOUNDARY = time.time()
    latency_count = state.pop(LATENCY_COUNT, None)
    latency_time = state.pop(LATENCY_TIME, None)
    throughput_in = state.pop(THROUGHPUT_IN, None)
    throughput_out = state.pop(THROUGHPUT_OUT, None)

    emit_statistics(t0, STAT_TIME_BOUNDARY,
                    ('latency_count', latency_count),
                    ('latency_time', latency_time),
                    ('throughput_in', throughput_in),
                    ('throughput_out', throughput_out))
    call_later(period, process_statistics, call_later, period)


def serialize_statistics(args):
    data = {'t0': args[0], 't1': args[1], 'func': 'Sink',
            'VUID': VUID}
    for name, stat in args[2]:
        data[name] = dict(stat) if stat else None
    return json.dumps(data)


def emit_statistics(t0, t1, *stats):
    for name, stat in stats:
        LOGGER.info("({}, {}) {}: {}".format(t0, t1, name, stat))
    if METRICS_HOST:
        transport.sendto(serialize_statistics((t0, t1, stats)).encode(),
                         (METRICS_HOST, METRICS_PORT))


def process_msg(buf):
    """Process individual messages into a local latency and throughput
    metrics collection"""
    data = json.loads(buf.decode('UTF-8'))

    # print output via logger.info
    LOGGER.info(data['msg'])
    # Compute latency and store it in state
    dt = time.time() - data['feed_time']
    state.add('{:.09f} s'.format(10**math.ceil(math.log(dt, 10))),
              1, LATENCY_COUNT)
    state.add('{:.09f} s'.format(10**math.ceil(math.log(dt, 10))),
              dt, LATENCY_TIME)
    # Measure throughput
    state.add(int(time.time()), 1, THROUGHPUT_OUT)
    state.add(int(time.time()), 1, THROUGHPUT_IN)


def post(uri, data=None, json=None):
    response = requests.post(uri, data=data, json=json)


class UDPMessageQueue(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        try:
            process_msg(data)
        except:
            LOGGER.exception('Error encountered during msg processing')

    def connection_lost(self, exc):
        self.transport = None


@click.command()
@click.option('--address', default='127.0.0.1:10000',
              help='Address to listen on')
@click.option('--metrics-address', default=None,
              help='Host:port for metrics receiver. No metrics are sent out'
              ' if this is left blank')
@click.option('--console-log', is_flag=True, default=False,
              help='Log output to stdout.')
@click.option('--file-log', is_flag=True, default=False,
              help='Log output to file.')
@click.option('--stats-period', default=60,
              help='The period over which stats are measured.')
@click.option('--log-level', default='info', help='Log level',
              type=click.Choice(['debug', 'info', 'warn', 'error']))
@click.option('--vuid', default=None,
              help='The VUID of the node. A VUID will be generated if none'
              ' is provided.')
def start(address,
          metrics_address,
          console_log,
          file_log,
          stats_period,
          log_level,
          vuid):
    global VUID
    if vuid:
        VUID = vuid
    else:
        VUID = get_vuid()

    # Parse address string to host and port str:int pair
    host, port = [f(x) for f, x in
                  zip((str, int), address.split(':'))]
    global METRICS_HOST
    global METRICS_PORT
    if metrics_address:
        METRICS_HOST, METRICS_PORT = [f(x) for f, x in
                                      zip((str, int),
                                          metrics_address.split(':'))]
    else:
        METRICS_HOST, METRICS_PORT = None, None

    # Create a global logger
    global LOGGER
    LOGGER = fs.get_logger('logs/{}.{}'.format('MQ',
                                               '{}-{}'.format(host, port)),
                           stream_out=console_log,
                           file_out=file_log,
                           level=log_level)
    LOGGER.info('Starting Sink...')
    LOGGER.info('Address: %s', (host, port))

    # Create the main event loop object
    loop = asyncio.get_event_loop()
    # One protocol instance will be created to serve all client requests
    listen = loop.create_datagram_endpoint(
        UDPMessageQueue, local_addr=(host, port))
    global transport
    transport, protocol = loop.run_until_complete(listen)

    # Create the call_later partial function
    call_later = loop.call_later
    # Start the listener event loop and run until SIGINT
    try:
        call_later(stats_period, process_statistics, call_later, stats_period)
        loop.run_forever()
    except KeyboardInterrupt:
        LOGGER.info("Shutting down")
        process_statistics(call_later, stats_period)
        pass

    transport.close()
    loop.close()


if __name__ == '__main__':
    start()
