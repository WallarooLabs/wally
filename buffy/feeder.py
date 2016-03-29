#!/usr/bin/env python3

"""Feedder feeds lines to a message queue from a list of sources
"""


import click
import time

import functions.fs as fs
import worker


@click.option('--address', default='127.0.0.1:10000',
              help='Host:port for MQ address')
@click.option('--delay', default=0.000000001,
              help='Loop delay when idling.')
@click.option('--path', multiple=True,
              help='Path to source file')
@click.option('--console-log', is_flag=True, default=False,
              help='Log output to stdout.')
@click.option('--file-log', is_flag=True, default=False,
              help='Log output to file.')
@click.option('--log-level', default='info', help='Log level',
              type=click.Choice(['debug', 'info', 'warn', 'error']))
@click.command()
def feed(address, delay, path, console_log, file_log, log_level):
    # parse input and output address strings into address tuples
    host, port = [f(x) for f, x in
                  zip((str, int), address.split(':'))]

    # Create logger
    global LOGGER
    logger = fs.get_logger('logs/{}.{}.{}'.format('feeder', host, port),
                           stream_out=console_log,
                           file_out=file_log,
                           level=log_level)

    logger.info('Starting feeder...')
    logger.info('Address: %s', address)
    for p in path:
        logger.info('Path: %s', p)
    LOGGER = logger
    worker.LOGGER = LOGGER

    # Open the source files and get their sizes (by seeking to the end)
    sources = [open(p, 'rb') for p in path]
    sources = [(s, s.seek(0,2)) for s in sources]
    # Place the file cursors back at the beginning of the file
    for source, _ in sources:
        source.seek(0)
    c = 0
    while sources:
        source, source_size = sources[c % len(sources)]
        msg = source.readline().decode() + '999={}\x01'.format(time.time())
        if not msg and source.tell() >= source_size:
            logger.info('Removing file %s' % source.name)
            sources.remove((source, source_size))
            continue
        worker.udp_put(msg, host, port)
        c += 1
        time.sleep(delay)



if __name__ == '__main__':
    feed()
