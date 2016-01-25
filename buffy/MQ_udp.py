#!/usr/bin/env python3.5

import asyncio
import click
import sys
import time

from functions import mq_parse
import functions.fs as fs


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
                LOGGER.info('Edge latency: {:.09f} s'.format(dt))
            except asyncio.queues.QueueEmpty:
                self.transport.sendto(mq_parse.encode(''),
                                      addr)
        elif verb == 'SIZE':
            self.transport.sendto(
                mq_parse.encode('{}'.format(QUEUE.qsize())),
                addr)

    def connection_lost(self, exc):
        LOGGER.info('\n'.join(('connection closed?', str(exc))))
        self.transport = None


def parse_cmd_args():
    # Get host and port from command line
    host = sys.argv[1].split(':')[0]
    port = int(sys.argv[1].split(':')[1])
    return host, port


@click.command()
@click.option('--address', default='127.0.0.1:10000',
              help='Address to listen on')
@click.option('--console-log', is_flag=True, default=False,
              help='Log output to stdout.')
@click.option('--file-log', is_flag=True, default=False,
              help='Log output to file.')
def start(address, console_log, file_log):
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

    # Start the listener event loop and run until SIGINT
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        LOGGER.info("Shutting down")
        qsize = QUEUE.qsize()
        LOGGER.info("Queue size: {}".format(qsize))
        pass

    transport.close()
    loop.close()


if __name__ == '__main__':
    start()
