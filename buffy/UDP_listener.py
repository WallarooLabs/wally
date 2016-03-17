#!/usr/bin/env python3

"""UDP_listener listens on a specified address and port and emits
whatever it receives to cosnole.
"""


import click
import socket



@click.command()
@click.option('--address', default='127.0.0.1:10000',
              help='Address to listen on')
def listen(address):
    host, port = [f(x) for f, x in
                  zip((str, int), address.split(':'))]
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))

    while True:
        buf = sock.recv(65507)
        if buf:
            print(buf)


if __name__ == '__main__':
    listen()
