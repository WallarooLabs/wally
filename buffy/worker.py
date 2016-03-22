#!/usr/bin/env python3

'''
Worker takes a MQ node as input, a MQ node as output, and a filename from
which to pull its function.
It then runs in a rate-limiting loop performing the following steps in order:
1. pull from input
2. apply function to input
3. push result to output


The function file should be of the following format:

    #!/usr/bin/env python3

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
import functools
import json
import math
import socket
import time
from threading import Timer

import functions.fs as fs
from functions import get_function
import functions.mq_parse as mq_parse
from functions import state
from functions.vuid import get_vuid


VUID = None


THROUGHPUT_IN = 'throughput_in'
THROUGHPUT_OUT = 'throughput_out'
LATENCY_COUNT = 'latency_count'
LATENCY_TIME = 'latency_time'


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
    LOGGER.debug("Sent datagram to ({}, {})".format(host, port))
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
    LOGGER.debug("Received datagram from ({}, {})".format(host, port))
    # join buffers in the accumulator
    output = b''.join(buf_array)
    return mq_parse.decode(output)


def udp_put(msg, host=None, port=None):
    """Put a single message into an output queue.
    """
    sock = get_socket(False)
    sock.sendto(mq_parse.encode('PUT:{}'.format(msg)),
                (host, port))
    LOGGER.debug("Sent datagram to ({}, {})".format(host, port))


def udp_dump(msg, host=None, port=None):
    """Dump a single message into an output socket.
    """
    sock = get_socket(False)
    sock.sendto(msg.encode(encoding='UTF-8'),
                (host, port))
    LOGGER.debug("Sent datagram to ({}, {})".format(host, port))


def run_engine(choose_input, inputs, funcs, outputs, delay):
    # Start the main loop
    while True:
        input_type = choose_input()
        input = inputs[input_type]()
        t0 = time.time()
        if input == '':
            time.sleep(delay)
            continue
        # Measure throughput
        state.add(int(time.time()), 1, THROUGHPUT_IN)
        output = funcs[input_type](input)
        if output:
            if isinstance(output, tuple):
                choice, output = output
            else:
                choice = 0
            (outputs[input_type][hash(choice) % len(outputs[input_type])]
             (output))
        dt = time.time()-t0
        # Measure throughput
        state.add(int(time.time()), 1, THROUGHPUT_OUT)
        # Add latency to histogram
        state.add('{:.09f} s'.format(10**math.ceil(math.log(dt, 10))),
                  dt, LATENCY_TIME)
        state.add('{:.09f} s'.format(10**math.ceil(math.log(dt, 10))),
                  1, LATENCY_COUNT)


STAT_TIME_BOUNDARY = time.time()
STATS = None


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
    timer = call_later(period, process_statistics, (call_later, period))
    timer.daemon = True
    timer.start()


def emit_statistics(t0, t1, *stats):
    for name, stat in stats:
        LOGGER.info("({}, {}) {}: {}".format(t0, t1, name, stat))
    global STATS
    STATS = (t0, t1, stats)


def serialize_statistics(args):
    data = {'t0': args[0], 't1': args[1], 'func': FUNC_NAME, 'VUID': VUID}
    for name, stat in args[2]:
        data[name] = dict(stat) if stat else None
    return json.dumps(data)


@click.option('--input-address', default='127.0.0.1:10000',
              help='Host:port for input address')
@click.option('--output-address', default='127.0.0.1:10000',
              help='Host:port for output address', multiple=True)
@click.option('--output-type', type=click.Choice(['queue', 'socket']))
@click.option('--metrics-address', default=None,
              help='Host:port for metrics receiver. No metrics are sent out'
              ' if this is left blank')
@click.option('--console-log', is_flag=True, default=False,
              help='Log output to stdout.')
@click.option('--file-log', is_flag=True, default=False,
              help='Log output to file.')
@click.option('--delay', default=0.000001,
              help='Loop delay when idling.')
@click.option('--function', default='passthrough',
              help='The FUNC_NAME value of the function to be loaded '
              'from the functions submodule.')
@click.option('--stats-period', default=60,
              help='The period over which stats are measured.')
@click.option('--log-level', default='info', help='Log level',
              type=click.Choice(['debug', 'info', 'warn', 'error']))
@click.option('--vuid', default=None,
              help='The VUID of the node. A VUID will be generated if none'
              ' is provided.')
@click.command()
def start(input_address,
          output_address,
          output_type,
          metrics_address,
          console_log,
          file_log,
          delay,
          function,
          stats_period,
          log_level,
          vuid):
    global VUID
    if vuid:
        VUID = vuid
    else:
        VUID = get_vuid()

    # parse input and output address strings into host and port params
    input_host, input_port = [f(x) for f, x in
                              zip((str, int), input_address.split(':'))]
    output_hosts, output_ports = [], []
    for addr in output_address:
        host, port = [f(x) for f, x in zip((str, int), addr.split(':'))]
        output_hosts.append(host)
        output_ports.append(port)
    if metrics_address:
        metrics_host, metrics_port = [f(x) for f, x in
                                      zip((str, int),
                                          metrics_address.split(':'))]
    else:
        metrics_host, metrics_port = None, None

    if output_type == 'queue':
        output_func = udp_put
    else:
        output_func = udp_dump

    # Create partial functions for input and output
    udp_input = functools.partial(udp_get, host=input_host, port=input_port)
    udp_outputs = []
    for host, port in zip(output_hosts, output_ports):
        udp_outputs.append(functools.partial(output_func, host=host,
                           port=port))
    # Import the function to be applied to data from the queue
    func, func_name = get_function(function)
    global FUNC_NAME
    FUNC_NAME = func_name
    # Create partial functions for metrics processing
    def stats_input():
        global STATS
        if STATS:
            data = STATS
            STATS = None
            return data
        return None
    stats_outputs = [functools.partial(udp_dump, host=metrics_host,
                                       port=metrics_port)]

    if metrics_address:
        def choose_input():
            global STATS
            if STATS:
                return 'stats'
            return 'msg'
    else:
        def choose_input():
            return 'msg'

    # Create input, func, and output maps keyed on 'input_type'
    inputs = {'msg': udp_input,
              'stats': stats_input}
    funcs = {'msg': func,
             'stats': serialize_statistics}
    outputs = {'msg': udp_outputs,
               'stats': stats_outputs}

    # Create delayed callback alias from Timer
    call_later = Timer

    # Create logger
    global LOGGER
    logger = fs.get_logger('logs/{}.{}.{}'
                           .format(func_name,
                                   '{}'.format(input_address),
                                   '{}'.format(output_address)),
                           stream_out=console_log,
                           file_out=file_log,
                           level=log_level)

    logger.info('Starting worker...')
    logger.info('VUID: %s', VUID)
    logger.info('FUNC_NAME: %s', func_name)
    logger.info('input_addr: %s', input_address)
    logger.info('output_addr: %s', output_address)
    LOGGER = logger

    try:
        timer = call_later(stats_period, process_statistics, (call_later,
                           stats_period))
        timer.daemon = True
        timer.start()
        run_engine(choose_input, inputs, funcs, outputs, delay)
    except KeyboardInterrupt:
        logger.info("Latency_count: {}".format(state.pop(LATENCY_COUNT,
                                                         None)))
        logger.info("Latency_time: {}".format(state.pop(LATENCY_TIME, None)))


if __name__ == '__main__':
    start()
