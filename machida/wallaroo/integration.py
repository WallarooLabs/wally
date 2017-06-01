import io
import socket
import struct
import subprocess
import threading
import time

class StoppableThread(threading.Thread):
    def __init__(self):
        super(StoppableThread, self).__init__()
        self.daemon = True
        self.stop_event = threading.Event()

    def stop(self):
        self.stop_event.set()

    def stopped(self):
        return self.stop_event.is_set()


class SingleSocketReceiver(StoppableThread):
    def __init__(self, sock, accumulator):
        super(SingleSocketReceiver, self).__init__()
        self.sock = sock
        self.data = accumulator

    def run(self):
        while not self.stopped():
            header = self.sock.recv(4)
            if not header:
                self.stop()
                continue
            expect = struct.unpack('>L', header)[0]
            data = self.sock.recv(expect)
            if not data:
                self.stop()
            else:
                self.data.append(''.join((header, data)))
                time.sleep(0.000001)

    def stop(self):
        super(self.__class__, self).stop()
        self.sock.close()


class TCPReceiver(StoppableThread):
    """
    TCPReceiver listens on a (host,port) pair and writes any incoming data
    to an in-memory byte buffer.
    Use get_buffered_reader()` to get a readable buffer once the TCPReceiver
    has stopped.
    """

    def __init__(self, host, port, max_connections=10):
        """
        Listen on a (host, port) pair for up to max_connections connections.
        Each connection is handled by a separate client thread.
        """
        super(TCPReceiver, self).__init__()
        self.host = host
        self.port = port
        self.max_connections = max_connections
        # use an in-memory byte buffer
        self.data = []
        # Create a socket and start listening
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.clients = []

    def run(self):
        self.sock.bind((self.host, self.port))
        self.sock.listen(self.max_connections)
        while not self.stopped():
            (clientsocket, address) = self.sock.accept()
            cl = SingleSocketReceiver(clientsocket, self.data)
            print("Opening TCP Reader from ({}, {}) on port {}.".format(
                self.host, self.port, address[1]))
            self.clients.append(cl)
            cl.start()

    def stop(self):
        super(TCPReceiver, self).stop()
        self.sock.close()
        for cl in self.clients:
            cl.stop()

    def get_buffered_reader(self):
        """Get a buffered reader for the data received from the socket"""
        return io.BufferedReader(io.BytesIO(''.join(self.data)))


class Metrics(TCPReceiver):
    """An alias for TCPReceiver"""
    pass


class Sink(TCPReceiver):
    """An alias for TCPReceiver"""
    pass


class Sender(threading.Thread):
    def __init__(self, host, port, reader, batch_size=1, interval=0.001,
                 header_size=4, header_fmt='>L'):
        super(Sender, self).__init__()
        self.daemon = True
        self.reader = reader
        self.batch_size = batch_size
        self.batch = []
        self.interval = interval
        self.header_size = header_size
        self.header_fmt = header_fmt
        self.last_sent = 0
        self.host = host
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)

    def send(self, bs):
        self.sock.sendall(bs)

    def batch_append(self, bs):
        self.batch.append(bs)

    def batch_send(self):
        if len(self.batch) >= self.batch_size:
            if (time.time() - self.last_sent) < self.interval:
                time.sleep(max(0, interval - (time.time() - self.last_sent)))
            self.batch_send_final()

    def batch_send_final(self):
        if self.batch:
            self.send(''.join(self.batch))
            self.batch = []

    def run(self):
        print("Sender connecting to ({}, {}).".format(self.host, self.port))
        self.sock.connect((self.host, self.port))
        while True:
            header = self.reader.read(self.header_size)
            if not header:
                break
            expect = struct.unpack(self.header_fmt, header)[0]
            body = self.reader.read(expect)
            if not body:
                break
            self.batch_append(''.join((header, body)))
            self.batch_send()
            time.sleep(0.000000001)
        self.batch_send_final()
        self.sock.close()


def SequenceGenerator(stop=1000, start=0, header_size=4, header_fmt='>L'):
    for x in xrange(start+1, stop+1):
        yield struct.pack(header_fmt, 8)
        yield struct.pack('>Q', x)


def ListGenerator(items, to_string=lambda s: str(s), header_size=4,
                  header_fmt='>L'):
    for val in items:
        strung = to_string(val)
        s = struct.pack('>{}s'.format(len(strung)), strung)
        yield struct.pack('>L', len(s))
        yield s


class HeaderGeneratorReader(object):
    def __init__(self, generator):
        self.gen = generator
        self.overflow = ''

    def read(self, num):
        remaining = num
        out = io.BufferedWriter(io.BytesIO())
        remaining -= out.write(self.overflow)
        while remaining > 0:
            try:
                remaining -= out.write(self.gen.next())
            except StopIteration:
                break
        # first num bytes go to return, remainder to overflow
        out.seek(0)
        r = out.raw.read(num)
        self.overflow = out.raw.read()
        return r


class Runner(object):
    pass


class Validator(object):
    pass
