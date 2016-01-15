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

import datetime
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

def udp_get(host, port):
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


def udp_put(host, port, msg):
    """Put a single message into an output queue.
    """
    sock = get_socket(False)
    sock.sendto(mq_parse.encode('PUT:{}'.format(msg)),
                (host, port))


def start(func, func_name, input_addr, output_addr,
          delay=0.01, stream_out=True, file_out=False):

    # Create logger
    logger = fs.get_logger('logs/{}.{}.{}'.format(FUNC_NAME,
                                                 '{}-{}'.format(*input_addr),
                                                 '{}-{}'.format(*output_addr)),
                           stream_out=True,
                           file_out=False)


    logger.info('Starting worker...')
    logger.info('FUNC_NAME: %s', FUNC_NAME)
    logger.info('input_addr: %s', input_addr)
    logger.info('output_addr: %s', output_addr)

    while True:
        input = udp_get(*input_addr)
        t0 = time.time()
        if input == '':
            time.sleep(delay)
            continue
        output = func(input)
        udp_put(*output_addr, output)
        dt = time.time()-t0
        logger.info('Vertex latency: {:.09f} s'.format(dt))


def parse_cmd_args():
    # parse command line variables
    input_addr = (sys.argv[1].split(':')[0], int(sys.argv[1].split(':')[1]))
    output_addr = (sys.argv[2].split(':')[0], int(sys.argv[2].split(':')[1]))
    return input_addr, output_addr


if __name__ == '__main__':
    STREAM_OUT = True
    FILE_OUT = False
    DELAY = 0.000001
    FUNC_NAME = 'Passthrough'

    # Import the function to be applied to data from the queue
    func = get_function(FUNC_NAME)

    # Get arguments from command line (input and output address values)
    input_addr, output_addr = parse_cmd_args()

    # Start the main loop
    start(func=func,
          func_name=FUNC_NAME,
          input_addr=input_addr,
          output_addr=output_addr,
          delay=DELAY,
          stream_out=STREAM_OUT,
          file_out=FILE_OUT)

