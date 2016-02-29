#!/usr/bin/env python3

"""
fs provides prebaked primitives for filesystem interaction. Since modularity
and composability are explicit goals of this project, classes and functions
that interact with the filesystem should be defined here.
"""

import datetime
import logging
import time
import uuid


# Make sure we're using UTC for our timestmaps
logging.Formatter.converter = time.gmtime


def get_uuid():
    return uuid.uuid4()


def get_stream_handler(level):
    sh = logging.StreamHandler()
    sh.setLevel(level)
    return sh


def get_file_handler(name, level):
    fh = logging.FileHandler(filename='{}.{}.log'.format(name, get_uuid()))
    fh.setLevel(level)
    return fh


class UTCMicroSecondFormatter(logging.Formatter):
    converter = datetime.datetime.utcfromtimestamp

    def formatTime(self, record, datefmt=None):
        ct = self.converter(record.created)
        if datefmt:
            s = ct.strftime(datefmt)
        else:
            t = ct.strftime("%Y-%m-%d %H:%M:%S")
            s = "%s,%03d" % (t, record.msecs)
        return s


def get_formatter(fmt='%(asctime)s %(message)s',
                  datefmt='%Y-%m-%d %H:%M:%S.%f'):
    formatter = UTCMicroSecondFormatter(fmt=fmt, datefmt=datefmt)
    return formatter


LOG_LEVELS = {'debug': logging.DEBUG,
              'info': logging.INFO,
              'warn': logging.WARN,
              'error': logging.ERROR,
              'critical': logging.CRITICAL,
              'fatal': logging.FATAL}


def get_logger(name, level='info', stream_out=False,file_out=False):
    # Create the logger object and set it's level
    level = LOG_LEVELS.get(level.lower(), logging.INFO)
    logger = logging.getLogger(name)
    logger.setLevel(level)
    # Create formatter
    formatter = get_formatter()
    if file_out:
        # Create basic file handler, without rotation or compression
        fh = get_file_handler(name, level)
        fh.setFormatter(formatter)
        logger.addHandler(fh)
    if stream_out:
        # Create basic stream handler outputing to console
        sh = get_stream_handler(level)
        sh.setFormatter(formatter)
        logger.addHandler(sh)
    return logger
