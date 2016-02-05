#!/usr/bin/env python3

import asyncio
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


def start(host, port, stream_out=True, file_out=False):
    global LOGGER
    LOGGER = fs.get_logger('logs/{}.{}'.format('MQ',
                                               '{}-{}'.format(host, port)),
                           stream_out=True,
                           file_out=False)


    LOGGER.info('Starting Message Queue...')
    LOGGER.info('Address: %s', (host, port))
    loop = asyncio.get_event_loop()
    # One protocol instance will be created to serve all client requests
    listen = loop.create_datagram_endpoint(
        UDPMessageQueue, local_addr=(host, port))
    transport, protocol = loop.run_until_complete(listen)

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
    STREAM_OUT = True
    FILE_OUT = False

    host, port = parse_cmd_args()

    QUEUE = asyncio.Queue()
    start(host, port, STREAM_OUT, FILE_OUT)

