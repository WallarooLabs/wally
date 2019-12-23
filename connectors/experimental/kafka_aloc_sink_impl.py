#!/usr/bin/env python3

from abc import ABC, abstractmethod
import asyncore
import asynchat
import logging
import math
import os
import random
import re
import socket
import struct
import sys
import threading
import time
import traceback
import aloc_sink_impl

from wallaroo.experimental import connector_wire_messages as cwm
from aloc_sink_impl import *

class KafkaSink_TwoPC_Output_LocalFilesystem(TwoPC_Output):
    def __init__(self, out_path, producer, topic):
        self._out_path = out_path
        self._producer = producer
        self._topic = topic
        self.out = None
        self._out = None
        self.txn_log = None
        self._instance_name = None
        self._th = TwoPC_TxnlogHelper

    def open(self, instance_name):
        self._instance_name = instance_name
        opath = self._out_path + "." + instance_name
        with open(opath, 'ab') as tmp:
            None # Create the file if it doesn't already exist
        self._out = open(opath, 'r+b')
        self._out.seek(0, 2) ## Seek to end of the file
        self._out_offset = self._out.tell()
        logging.debug('TwoPC_Output_LocalFilesystem.open: worker {} self._out_offset = {}'.format(instance_name, self._out_offset))

        tlpath = self._out_path + "." + instance_name + ".txnlog"
        self._txn_log = open(tlpath, 'ab')
        self._txn_log_path = tlpath

        return self._out_offset

    def truncate_and_seek_to(self, truncate_offset):
        self._out.truncate(truncate_offset)
        self._out.seek(truncate_offset)
        self._out_offset = truncate_offset
        self.flush_fsync_txnlog()
        logging.info("truncate_and_seek_to: truncate worker {} to {}".format(
            self._instance_name, truncate_offset))

        return self._out_offset

    def out_tell(self):
        """Used only for sanity checking & diagnostic logging/spam."""
        return self._out.tell()

    def flush_fsync_all(self):
        self.flush_fsync_out()
        self.flush_fsync_txnlog()

    def flush_fsync_out(self):
        self.flush_fsync(self._out)

    def flush_fsync_txnlog(self):
        self.flush_fsync(self._txn_log)

    def append_output(self, bs, append_offset):
        if append_offset != self._out_offset:
            raise Exception("append_out: worker {}: append_offset {} != _out_offset {}".format(
                self._instance_name, append_offset, self._out_offset))
        ret = self._out.write(bs)
        self._producer.send(self._topic, bs)
        self._out_offset += ret
        logging.debug("write_out: ret = {} len(bs) = {} new offset {}".format(
            ret, len(bs), self._out_offset))
        return (ret, self._out_offset)

    def append_txnlog(self, log_item):
        if self._txn_log is not None:
            bs = self._th.serialize_txnlog_item(log_item)
            ret = self._txn_log.write(bs)
            self.flush_fsync_txnlog()
            return ret
        else:
            return -1

    def read_chunk(self, what, should, go, here):
        raise Exception

    def read_txnlog_lines(self):
        return self._read_file_lines(self._txn_log_path)

    def _read_file(self, path):
        with open(path, 'rb') as f:
            return f.read(-1)

    def _read_file_lines(self, path):
        a = []
        with open(path, 'rb') as f:
            for l in f:
                a.append(l)
            return a

    def flush_fsync(self, file):
        """
        Return only if 100% successful.
        """
        x = file.flush()
        if x:
            logging.critical('flush failed: {}'.format(x))
            sys.exit(66)
        x = os.fsync(file.fileno())
        if x:
            logging.critical('fsync failed: {}'.format(x))
            sys.exit(66)

    # The file naming convention we use is "output.workername.TS"
    # and "output.workername.TS.txnlog".  This scheme is compatible
    # with the "1-to-1-passthrough-verify.sh" script: it examines the
    # sink output dir for all files with ".txnlog" suffix and then
    # chops off that suffix to find the corresponding output file.
    # After that, all of "1-to-1-passthrough-verify.sh" output
    # order mapping is done by 2PC commit timestamps.
    def leaving_workers(self, leaving_workers):
        for w in leaving_workers:
            opath = self._out_path + "." + w
            mv_path1 = "{}.{}".format(opath, time.time())
            cmd1 = "mv {} {} > /dev/null 2>&1".format(opath, mv_path1)
            cmd2 = "mv {}.txnlog {}.txnlog > /dev/null 2>&1".format(opath, mv_path1)
            logging.info("leaving worker: run: {}".format(cmd1))
            logging.info("leaving worker: run: {}".format(cmd2))
            os.system(cmd1)
            os.system(cmd2)
