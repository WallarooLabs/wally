from testing.tools.integration.__init__ import *

import datetime
import io
import socket
import struct
import sys
import threading
import time

class MyReader(object):
    """
    A BufferedReader interface over a bytes generator
    """
    def __init__(self, generator):
        self.gen = generator
        self.overflow = ''.encode()

    def read(self, num):
        remaining = num
        out = io.BufferedWriter(io.BytesIO())
        remaining -= out.write(self.overflow)
        while remaining > 0:
            try:
                remaining -= out.write(self.gen.__next__())
            except StopIteration:
                break
        # first num bytes go to return, remainder to overflow
        out.seek(0)
        r = out.raw.read(num)
        self.overflow = out.raw.read()
        return r

def mysequence_generator(stop=1000, start=0, header_fmt='>I', partition=''):
    """
    Generate a sequence of integers, encoded as big-endian U64.

    `stop` denotes the maximum value of the sequence (inclusive)
    `start` denotes the starting value of the sequence (exclusive)
    `header_length` denotes the byte length of the length header
    `header_fmt` is the format to use for encoding the length using
    `struct.pack`
    `partition` is a string representing the optional partition key. It is
    empty by default.
    """
    size = 8 + len(partition)
    fmt = '>Q{}s'.format(len(partition)) if partition else '>Q'
    for x in range(start+1, stop+1):
        struct.pack(header_fmt, size)
        yield struct.pack(header_fmt, size)
        if partition:
            yield struct.pack(fmt, x, partition.encode())
        else:
            yield struct.pack(fmt, x)

class MySender(StoppableThread):
    """
    Send length framed data to a destination (addr).

    `address` is the full address in the host:port format
    `reader` is a Reader instance
    `batch_size` denotes how many records to send at once (default=1)
    `interval` denotes the minimum delay between transmissions, in seconds
        (default=0.001)
    `header_length` denotes the byte length of the length header
    `header_fmt` is the format to use for encoding the length using
        `struct.pack`
    `reconnect` is a boolean denoting whether sender should attempt to
        reconnect after a connection is lost.
    """
    def __init__(self, address, reader, batch_size=1, interval=0.001,
                 header_fmt='>I', reconnect=False):
        print("Sender({address}, {reader}, {batch_size}, {interval},"
            " {header_fmt}, {reconnect}) created".format(
                address=address, reader=reader, batch_size=batch_size,
                interval=interval, header_fmt=header_fmt,
                reconnect=reconnect))
        super(MySender, self).__init__()
        self.daemon = True
        self.reader = reader
        self.batch_size = batch_size
        self.batch = []
        self.interval = interval
        self.header_fmt = header_fmt
        self.header_length = struct.calcsize(self.header_fmt)
        self.last_sent = 0
        self.address = address
        (host, port) = address.split(":")
        self.host = host
        self.port = int(port)
        self.name = 'Sender'
        self.error = None
        self._bytes_sent = 0
        self.reconnect = reconnect
        self.pause_event = threading.Event()
        self.start_time = None

    def pause(self):
        self.pause_event.set()

    def paused(self):
        return self.pause_event.is_set()

    def resume(self):
        self.pause_event.clear()

    def send(self, bs):
        self.sock.sendmsg(bs)
        self._bytes_sent += len(bs)

    def bytes_sent(self):
        return self._bytes_sent

    def batch_append(self, bs):
        self.batch.append(bs)

    def batch_send(self):
        if len(self.batch) >= self.batch_size:
            self.batch_send_final()
            time.sleep(self.interval)

    def batch_send_final(self):
        if len(self.batch) > 0:
            self.send(self.batch)
            self.batch = []

    def run(self):
        self.start_time = datetime.datetime.now()
        while not self.stopped():
            try:
                print("Sender connecting to ({}, {})."
                             .format(self.host, self.port))
                self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
                self.sock.connect((self.host, self.port))
                while not self.stopped():
                    while self.paused():
                        # make sure to empty the send buffer before
                        #entering pause state!
                        self.batch_send_final()
                        time.sleep(0.001)
                    header = self.reader.read(self.header_length)
                    if not header:
                        self.maybe_stop()
                        break
                    expect = struct.unpack(self.header_fmt, header)[0]
                    body = self.reader.read(expect)
                    if not body:
                        self.maybe_stop()
                        break
                    self.batch_append(header)
                    self.batch_append(body)
                    self.batch_send()
                    time.sleep(0.000000001)
                self.batch_send_final()
                self.sock.close()
            except KeyboardInterrupt:
                print("KeyboardInterrupt received.")
                self.stop()
                break
            except Exception as err:
                self.error = err
                print(err)
            if not self.reconnect:
                break
            if not self.stopped():
                print("Waiting 1 second before retrying...")
                time.sleep(1)

    def maybe_stop(self):
        if not self.batch:
            self.stop()

    def stop(self, error=None):
        print("Sender received stop instruction.")
        super(MySender, self).stop(error)
        if self.batch:
            print("Sender stopped, but send buffer size is {}"
                         .format(len(self.batch)))

wallaroo_hostsvc = sys.argv[1]
num_start = int(sys.argv[2])
num_end   = int(sys.argv[3])
batch_size = int(sys.argv[4])
interval = float(sys.argv[5])
num_part_keys = int(sys.argv[6])

senders = []
for p in range(0, num_part_keys):
	sender = MySender(wallaroo_hostsvc,
					MyReader(mysequence_generator(start=num_start, stop=num_end,
											  partition='key_%d' % p)),
                	batch_size=batch_size, interval=interval, reconnect=True)
	senders.append(sender)

for s in senders:
	s.start()
for s in senders:
	s.join()

sys.exit(0)