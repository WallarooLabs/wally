#!/usr/bin/env python3.5

'''
Worker takes a MQ node as input, a MQ node as output, and a filename from
which to pull its function.
It then runs in a rate-limiting loop performing the following steps in order:
1. pull from input
2. apply function to input
3. push result to output


The function file should be of the following format:

    #!/usr/bin/env python3.5

    def func(input):
        # process data
        if input == 'ping':
            output = 'pong'
        else:
            output = 'ping'
        # return output
        return output
'''

import click
import datetime
import functools
import logging
import socket
import sys
import time

import functions.mq_parse as mq_parse
import functions.fs as fs
from functions import get_function


SOCK_IN = None
SOCK_OUT = None
def get_socket(input=True):
    global SOCK_IN, SOCK_OUT
    if input:
        if not SOCK_IN or SOCK_IN._closed:
            # open UDP socket, non-blocking
            SOCK_IN = socket.socket(socket.AF_INET,
                                    socket.SOCK_DGRAM)
        return SOCK_IN
    else:
        if not SOCK_OUT or SOCK_OUT._closed:
            # open UDP socket, non-blocking
            SOCK_OUT = socket.socket(socket.AF_INET,
                                     socket.SOCK_DGRAM)
        return SOCK_OUT

def udp_get(host=None, port=None):
    """Get a single message from the message queue.
    Loop forever until a message is received or an interrupt is signaled.
    """
    sock = get_socket(True)
    sock.sendto(mq_parse.encode('GET'),
                (host, port))
    # parse response length
    length_length = mq_parse.hex_to_int(sock.recv(1, socket.MSG_PEEK)
                                        .decode(encoding='UTF-8'))
    msg_length = mq_parse.hex_to_int(
        sock.recv(1+length_length, socket.MSG_PEEK)[1:].decode('UTF-8'))
    total_length = 1 + length_length + msg_length
    # accumulate output in an array of byte buffers
    buf_array = []
    while total_length > 0:
        buf = sock.recv(65507)
        if len(buf) > 0:
            total_length -= len(buf)
            buf_array.append(buf)
    # join buffers in the accumulator
    output = b''.join(buf_array)
    return mq_parse.decode(output)


def udp_put(msg, host=None, port=None):
    """Put a single message into an output queue.
    """
    sock = get_socket(False)
    sock.sendto(mq_parse.encode('PUT:{}'.format(msg)),
                (host, port))


def udp_dump(msg, host=None, port=None):
    """Dump a single message into an output socket.
    """
    sock = get_socket(False)
    sock.sendto(msg.encode(encoding='UTF-8'),
                (host, port))


@click.command()
@click.option('--input-address', default='127.0.0.1:10000',
              help='Host and port pair of input address')
@click.option('--output-address', default='127.0.0.1:10000',
              help='Host and port pair of output address')
@click.option('--output-type', type=click.Choice(['queue', 'socket']))
@click.option('--console-log', is_flag=True, default=False,
              help='Log output to stdout.')
@click.option('--file-log', is_flag=True, default=False,
              help='Log output to file.')
@click.option('--delay', default=0.000001,
              help='Loop delay when idling.')
@click.option('--function', default='passthrough',
              help='The FUNC_NAME value of the function to be loaded '
              'from the functions submodule.')
def start(input_address, output_address, output_type, console_log, file_log,
        delay, function):
    # parse input and output address strings into address tuples
    input_host, input_port = [f(x) for f,x in
                             zip((str, int), input_address.split(':'))]
    output_host, output_port = [f(x) for f,x in
                                zip((str, int), output_address.split(':'))]


    if output_type == 'queue':
        output_func = udp_put
    else:
        output_func = udp_dump

    # Create partial functions for input and output
    input_func = functools.partial(udp_get, host=input_host, port=input_port)
    output_func = functools.partial(output_func, host=output_host, port=output_port)
    # Import the function to be applied to data from the queue
    func, func_name = get_function(function)

    # Create logger
    logger = fs.get_logger('logs/{}.{}.{}'
                           .format(func_name,
                                   '{}'.format(input_address),
                                   '{}'.format(output_address)),
                           stream_out=console_log,
                           file_out=file_log)


    logger.info('Starting worker...')
    logger.info('FUNC_NAME: %s', func_name)
    logger.info('input_addr: %s', input_address)
    logger.info('output_addr: %s', output_address)

    # Start the main loop
    while True:
        input = input_func()
        t0 = time.time()
        if input == '':
            time.sleep(delay)
            continue
        output = func(input)
        output_func(output)
        dt = time.time()-t0
        logger.info('Vertex latency: {:.09f} s'.format(dt))


if __name__ == '__main__':
    start()
