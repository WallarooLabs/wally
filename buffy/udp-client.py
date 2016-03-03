#!/usr/bin/env python3

import asyncio
import sys

from functions.mq_parse import decode, encode




class EchoClientProtocol(asyncio.DatagramProtocol):
    def __init__(self, message, loop):
        self.message = message
        self.loop = loop
        self.transport = None

    def connection_made(self, transport):
        self.transport = transport
        self.transport.sendto(encode(self.message))
        print('Data sent: {!r}'.format(self.message))

    def datagram_received(self, data, addr):
        print('Data received: {!r}'.format(decode(data)))
        self.transport.close()

    def error_received(self, exc):
        print('Error received:', exc)

    def connection_lost(self, exc):
        print("Socket closed.")
        loop = asyncio.get_event_loop()
        loop.stop()


def main():
    host = sys.argv[1].split(':')[0]
    port = int(sys.argv[1].split(':')[1])
    message = ' '.join(sys.argv[2:])

    loop = asyncio.get_event_loop()
    connect = loop.create_datagram_endpoint(
        lambda: EchoClientProtocol(message, loop),
        remote_addr=(host, port))
    transport, protocol = loop.run_until_complete(connect)
    loop.run_forever()
    transport.close()
    loop.close()


if __name__ == '__main__':
    main()
