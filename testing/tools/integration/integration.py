# Copyright 2017 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.


import io
import itertools
import logging
import os
import random
import re
import shlex
import socket
import struct
import subprocess
import tempfile
import threading
import time

from metrics_parser import MetricsParser


class StoppableThread(threading.Thread):
    """
    A convenience baseclass for daemonized, stoppable thread classes.
    """
    def __init__(self):
        super(StoppableThread, self).__init__()
        self.daemon = True
        self.stop_event = threading.Event()

    def stop(self):
        self.stop_event.set()

    def stopped(self):
        return self.stop_event.is_set()


class SingleSocketReceiver(StoppableThread):
    """
    Read length or newline encoded data from a socket and append it to an
    accumulator list.
    Multiple SingleSocketReceivers may write to the same accumulator safely,
    so long as they perform atomic writes (e.g. each append adds a single,
    complete entry).
    """

    __base_name__ = 'SingleSocketReceiver'

    def __init__(self, sock, accumulator, mode='framed', header_fmt='>I',
                 name=None):
        super(SingleSocketReceiver, self).__init__()
        self.sock = sock
        self.accumulator = accumulator
        self.mode = mode
        self.header_fmt = header_fmt
        self.header_length = struct.calcsize(self.header_fmt)
        if name:
            self.name = '{}:{}'.format(self.__base_name__, name)
        else:
            self.name = self.__base_name__

    def append(self, bs):
        if self.mode == 'framed':
            self.accumulator.append(bs)
        else:
            self.accumulator.append('{}\n'.format(bs))

    def run(self):
        if self.mode == 'framed':
            self.run_framed()
        else:
            self.run_newlines()

    def run_newlines(self):
        data = []
        while not self.stopped():
            buf = self.sock.recv(1024)
            if not buf:
                self.stop()
                if data:
                    self.append(''.join(data))
            # We must be careful not to accidentally join two separate lines
            # nor split a line
            split = buf.split('\n')  # '\n' show as '' in list after split
            s0 = split.pop(0)
            if s0:
                if data:
                    data.append(s0)
                    self.append(''.join(data))
                    data = []
                else:
                    self.append(s0)
            else:
                # s0 is '', so first line is a '\n', and overflow is a
                # complete message if it isn't empty
                if data:
                    self.append(''.join(data))
                    data = []
            for s in split[:-1]:
                self.append(s)
            if split:  # not an empty list
                if split[-1]:  # not an empty string, i.e. it wasn't a '\n'
                    data.append(split[-1])
            time.sleep(0.000001)

    def run_framed(self):
        while not self.stopped():
            header = self.sock.recv(self.header_length)
            if not header:
                self.stop()
                continue
            expect = struct.unpack(self.header_fmt, header)[0]
            data = self.sock.recv(expect)
            if not data:
                self.stop()
            else:
                self.append(''.join((header, data)))
                time.sleep(0.000001)

    def stop(self):
        super(self.__class__, self).stop()
        self.sock.close()


class TCPReceiver(StoppableThread):
    """
    Listen on a (host,port) pair and write any incoming data to an accumulator.

    If `port` is 0, an available port will be chosen by the operation system.
    `get_connection_info` may be used to obtain the (host, port) pair after
    `start()` is called.

    `max_connections` specifies the number of total concurrent connections
    supported.
    `mode` specifices how the receiver handles parsing the network stream
    into records. `'newlines'` will split on newlines, and `'framed'` will
    use a length-encoded framing, along with the `header_fmt` value (default
    mode is `'framed'` with `header_fmt='>I'`).

    You can read any data saved to the accumulator (a list) at any time
    by reading the `data` attribute of the receiver, although this attribute
    is only guaranteed to stop growing after `stop()` has been called.
    """
    __base_name__ = 'TCPReceiver'

    def __init__(self, host, port=0, max_connections=100, mode='framed',
                 header_fmt='>I'):
        """
        Listen on a (host, port) pair for up to max_connections connections.
        Each connection is handled by a separate client thread.
        """
        super(TCPReceiver, self).__init__()
        self.host = host
        self.port = port
        self.max_connections = max_connections
        self.mode = mode
        self.header_fmt = header_fmt
        self.header_length = struct.calcsize(self.header_fmt)
        # use an in-memory byte buffer
        self.data = []
        # Create a socket and start listening
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.sock.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        self.clients = []
        self.err = None
        self.event = threading.Event()

    def get_connection_info(self, timeout=10):
        is_connected = self.event.wait(timeout)
        if not is_connected:
            raise TimeoutError("{} Couldn't get connection info after {}"
                               " seconds".format(self.__base_name__, timeout))
        return self.sock.getsockname()

    def run(self):
        try:
            self.sock.bind((self.host, self.port))
            self.sock.listen(self.max_connections)
            self.host, self.port = self.sock.getsockname()
            self.event.set()
            while not self.stopped():
                (clientsocket, address) = self.sock.accept()
                cl = SingleSocketReceiver(clientsocket, self.data, self.mode,
                                          self.header_fmt,
                                          name='{}-{}'.format(
                                              self.__base_name__,
                                              len(self.clients)))
                logging.info("{}:{} accepting connection from ({}, {}) on "
                             "port {}."
                             .format(self.__base_name__, self.name, self.host,
                                     self.port, address[1]))
                self.clients.append(cl)
                cl.start()
        except Exception as err:
            self.err = err
            raise err

    def stop(self):
        super(TCPReceiver, self).stop()
        self.sock.close()
        for cl in self.clients:
            cl.stop()

    def save(self, path, mode=None):
        c = 0
        with open(path, 'wb') as f:
            for item in self.data:
                f.write(item[:self.header_length])
                if mode == 'giles':
                    f.write(struct.pack('>Q', c))
                    c += 1
                f.write(item[self.header_length:])

    def bytes_received(self):
        return sum(map(len, self.data))


class Metrics(TCPReceiver):
    __base_name__ = 'Metrics'


class MetricsStopper(StoppableThread):
    """
    Check every incoming message to metrics and stop it once the throughput
    is 0.
    """
    __base_name__ = 'MetricsStopper'
    _fmt = '>' + 'Q'*69

    def __init__(self, metrics, timeout=10):
        super(MetricsStopper, self).__init__()
        self.name = self.__base_name__
        self.metrics = metrics
        self.pos = 0
        self.timeout = timeout

    def run(self):
        self.last_check = time.time()
        while not self.stopped():
            # get current message
            pos = len(self.metrics.data) - 1
            if pos >= 0 and pos > self.pos:
                self.pos = pos
            else:
                if time.time() - self.last_check > self.timeout:
                    self.stop()
                time.sleep(1)
                continue
            dat = self.metrics.data[self.pos]
            self.last_check = time.time()
            if len(dat) < 552:
                time.sleep(1)
                continue
            try:
                tail = struct.unpack(self._fmt, dat[-552:])
                throughput = sum(tail[:65])
                if throughput == 0:
                    self.stop()
            except Exception as err:
                continue

    def stop(self):
        logging.debug('%s: stopping Metrics Receiver', self.name)
        self.metrics.stop()
        super(MetricsStopper, self).stop()


class Sink(TCPReceiver):
    __base_name__ = 'Sink'


class StopError(Exception):
    pass


class TimeoutError(StopError):
    pass


class ExpectationError(StopError):
    pass


class SinkExpect(StoppableThread):
    """
    Stop the sink after receiving an expected number of messages.
    """
    __base_name__ = 'SinkExpect'

    def __init__(self, sink, expected, timeout=30):
        super(SinkExpect, self).__init__()
        self.sink = sink
        self.expected = expected
        self.timeout = timeout
        self.name = self.__base_name__
        self.error = None

    def run(self):
        started = time.time()
        while not self.stopped():
            msgs = len(self.sink.data)
            if msgs > self.expected:
                self.error = ExpectationError('{}: has received too many '
                                              'messages. Expected {} but got '
                                              '{}.'.format(self.name,
                                                           self.expected,
                                                           msgs))
                self.stop()
                break
            if msgs == self.expected:
                self.stop()
                break
            if time.time() - started > self.timeout:
                self.error = TimeoutError('{}: has timed out after {} seconds'
                                          ', with {} messages. Expected {} '
                                          'messages.'.format(self.name,
                                                             self.timeout,
                                                             msgs,
                                                             self.expected))
                self.stop()
                break
            time.sleep(0.1)

    def stop(self):
        logging.debug('%s: stopping Sink Receiver', self.name)
        self.sink.stop()
        super(SinkExpect, self).stop()


class SinkAwaitValue(StoppableThread):
    """
    Stop the sink after receiving an expected value or values.
    """
    __base_name__ = 'SinkAwaitValue'

    def __init__(self, sink, values, timeout=30):
        super(SinkAwaitValue, self).__init__()
        self.sink = sink
        if isinstance(values, (list, tuple)):
            self.values = set(values)
        else:
            self.values = set((values, ))
        self.timeout = timeout
        self.name = self.__base_name__
        self.error = None
        self.position = 0

    def run(self):
        started = time.time()
        while not self.stopped():
            msgs = len(self.sink.data)
            if msgs and msgs > self.position:
                while self.position < msgs:
                    for val in list(self.values):
                        if self.sink.data[self.position] == val:
                            self.values.discard(val)
                            logging.debug("{} matched on value {}."
                                          .format(self.name,
                                                  val))
                    if not self.values:
                        self.stop()
                        break
                    self.position += 1
            if time.time() - started > self.timeout:
                self.error = TimeoutError('{}: has timed out after {} seconds'
                                          ', with {} messages. before '
                                          'receiving the awaited values '
                                          '{!r}.'.format(self.name,
                                                         self.timeout,
                                                         msgs,
                                                         self.values))
                self.stop()
                break
            time.sleep(0.1)

    def stop(self):
        logging.debug('%s: stopping Sink Receiver', self.name)
        self.sink.stop()
        super(SinkAwaitValue, self).stop()


class Sender(StoppableThread):
    """
    Send length framed data to a destination (host, port).

    `host` is the hostname to connect to
    `port` is the port to connect to
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
    def __init__(self, host, port, reader, batch_size=1, interval=0.001,
                 header_fmt='>I', reconnect=False):
        super(Sender, self).__init__()
        self.daemon = True
        self.reader = reader
        self.batch_size = batch_size
        self.batch = []
        self.interval = interval
        self.header_fmt = header_fmt
        self.header_length = struct.calcsize(self.header_fmt)
        self.last_sent = 0
        self.host = host
        self.port = port
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        self.name = 'Sender'
        self.error = None
        self._bytes_sent = 0
        self.reconnect = reconnect

    def send(self, bs):
        self.sock.sendall(bs)
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
        if self.batch:
            self.send(''.join(self.batch))
            self.batch = []

    def run(self):
        while not self.stopped():
            try:
                logging.info("Sender connecting to ({}, {})."
                             .format(self.host, self.port))
                self.sock.connect((self.host, self.port))
                while not self.stopped():
                    header = self.reader.read(self.header_length)
                    if not header:
                        self.maybe_stop()
                        break
                    expect = struct.unpack(self.header_fmt, header)[0]
                    body = self.reader.read(expect)
                    if not body:
                        self.maybe_stop()
                        break
                    self.batch_append(''.join((header, body)))
                    self.batch_send()
                    time.sleep(0.000000001)
                self.batch_send_final()
                self.sock.close()
            except KeyboardInterrupt:
                logging.info("KeyboardInterrupt received.")
                self.stop()
                break
            except Exception as err:
                self.error = err
                logging.error(err)
            if not self.reconnect:
                break
            logging.info("Waiting 1 second before retrying...")
            time.sleep(1)

    def maybe_stop(self):
        if not self.batch:
            self.stop()


def sequence_generator(stop=1000, start=0, header_fmt='>I'):
    """
    Generate a sequence of integers, encoded as big-endian U64.

    `stop` denotes the maximum value of the sequence (inclusive)
    `start` denotes the starting value of the sequence (exclusive)
    `header_length` denotes the byte length of the length header
    `header_fmt` is the format to use for encoding the length using
    `struct.pack`
    """
    for x in xrange(start+1, stop+1):
        yield struct.pack(header_fmt, 8)
        yield struct.pack('>Q', x)


def iter_generator(items, to_string=lambda s: str(s), header_fmt='>I'):
    """
    Generate a sequence of length encoded binary records from an iterator.

    `items` is the iterator of items to encode
    `to_string` is a function for converting items to a string
    (default:`lambda s: str(s)`)
    `header_fmt` is the format to use for encoding the length using
    `struct.pack`
    """
    for val in items:
        strung = to_string(val)
        yield struct.pack(header_fmt, len(strung))
        yield strung


def files_generator(files, mode='framed', header_fmt='>I'):
    """
    Generate a sequence of binary data stubs from a set of files.

    - `files`: either a single filepath or a list of filepaths.
        The same filepath may be provided multiple times, in which case it will
        be read that many times from start to finish.
    - `mode`: 'framed' or 'newlines'. If 'framed' is used, `header_fmt` is
        used to determine how many bytes to read each time. Default: 'framed'
    - `header_fmt`: the format of the length encoding header used in the files
        Default: '>I'
    """
    if isinstance(files, basestring):
        files = [files]

    for path in files:
        if mode == 'newlines':
            for l in newline_file_generator(path):
                yield l
        elif mode == 'framed':
            for l in framed_file_generator(path, header_fmt):
                yield l
        else:
            raise ValueError("`mode` must be either 'framed' or 'newlines'")


def newline_file_generator(filepath, header_fmt='>I'):
    """
    Generate length-encoded strings from a newline-delimited file.
    """
    with open(filepath, 'rb') as f:
        f.seek(0, 2)
        fin = f.tell()
        f.seek(0)
        while f.tell() < fin:
            o = f.readline().strip('\n')
            if o:
                yield struct.pack(header_fmt, len(o))
                yield o


def framed_file_generator(filepath, header_fmt='>I'):
    """
    Generate length encoded records from a length-framed binary file.
    """
    header_length = struct.calcsize(header_fmt)
    with open(filepath, 'rb') as f:
        while True:
            header = f.read(header_length)
            if not header:
                break
            expect = struct.unpack(header_fmt, header)[0]
            body = f.read(expect)
            if not body:
                break
            yield header
            yield body


class Reader(object):
    """
    A BufferedReader interface over a bytes generator
    """
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


class Runner(threading.Thread):
    """
    Run a shell application with command line arguments and save its stdout
    and stderr to a temporoary file.

    `get_output` may be used to get the entire output text up to the present,
    as well as after the runner has been stopped via `stop()`.
    """
    def __init__(self, cmd_string, name):
        super(Runner, self).__init__()
        self.daemon = True
        self.cmd_string = ' '.join(v.strip('\\').strip() for v in
                                  cmd_string.splitlines())
        self.cmd_args = shlex.split(self.cmd_string)
        self.error = None
        self.file = tempfile.NamedTemporaryFile()
        self.p = None
        self.name = name

    def run(self):
        try:
            logging.info("{}: Running:\n{}".format(self.name,
                                                   self.cmd_string))
            self.p = subprocess.Popen(args=self.cmd_args,
                                      stdout=self.file,
                                      stderr=subprocess.STDOUT)
            self.p.wait()
        except Exception as err:
            self.error = err
            logging.warn("{}: Stopped running!".format(self.name))
            raise err

    def stop(self):
        try:
            self.p.terminate()
        except:
            pass

    def kill(self):
        try:
            self.p.kill()
        except:
            pass

    def get_output(self):
        self.file.flush()
        with open(self.file.name, 'rb') as ro:
            return ro.read()

    def respawn(self):
        return Runner(self.cmd_string, self.name)


class RunnerReadyChecker(StoppableThread):
    __base_name__ = 'RunnerReadyChecker'
    pattern = re.compile('Application has successfully initialized')

    def __init__(self, runners, timeout=30):
        super(RunnerReadyChecker, self).__init__()
        self.runners = runners
        self.name = self.__base_name__
        self._path = self.runners[0].file.name
        self.timeout = timeout
        self.error = None

    def run(self):
        with open(self._path, 'rb') as r:
            started = time.time()
            while not self.stopped():
                r.seek(0)
                stdout = r.read()
                if not stdout:
                    time.sleep(0.1)
                    continue
                else:
                    if self.pattern.search(stdout):
                        logging.debug('Application reports it is ready.')
                        self.stop()
                        break
                if time.time() - started > self.timeout:
                    outputs = [(r.name, r.get_output()) for r in
                               self.runners]
                    outputs = '\n===\n'.join(('\n---\n'.join(t) for t in
                                              outputs))
                    self.error = TimeoutError(
                        'Application did not report as ready after {} '
                        'seconds. It had the following outputs:\n===\n{}'
                        .format(self.timeout, outputs))
                    self.stop()
                    break


class RunnerChecker(StoppableThread):
    __base_name__ = 'RunnerChecker'

    def __init__(self, runner, patterns, timeout=30):
        super(RunnerChecker, self).__init__()
        self.name = self.__base_name__
        self.runner_name = runner.name
        self._path = runner.file.name
        self.timeout = timeout
        self.error = None
        if isinstance(patterns, (list, tuple)):
            self.patterns = patterns
        else:
            self.patterns = [pattern]
        self.compiled = [re.compile(p) for p in patterns]

    def run(self):
        with open(self._path, 'rb') as r:
            last_match = 0
            started = time.time()
            while not self.stopped():
                r.seek(last_match)
                stdout = r.read()
                if not stdout:
                    time.sleep(0.1)
                    continue
                else:
                    match = self.compiled[0].search(stdout)
                    if match:
                        logging.debug('Pattern %r found in runner STDOUT.'
                                      % match.re.pattern)
                        self.compiled.pop(0)
                        last_match = 0
                        if self.compiled:
                            continue
                        self.stop()
                        break
                if time.time() - started > self.timeout:
                    r.seek(0)
                    stdout = r.read()
                    self.error = TimeoutError(
                        'Runner {!r} did not have patterns {!r}'
                        ' after {} '
                        'seconds. It had the following output:\n---\n{}'
                        .format(self.runner_name,
                                [rx.pattern for rx in self.compiled],
                                self.timeout, stdout))
                    self.stop()
                    break


def ex_validate(cmd):
    """
    Run a shell command, wait for it to exit.
    Return the tuple (Success (bool), output, return_code, command).
    """
    try:
        out = subprocess.check_output(shlex.split(cmd),
                                      stderr=subprocess.STDOUT)
    except subprocess.CalledProcessError as err:
        return (False, err.output, err.returncode, err.cmd)
    return (True, out, 0, shlex.split(cmd))


def setup_resilience_path(res_dir):
    # create resilience data directory if it doesn't already exist
    if not os.path.exists(res_dir):
        create_resilience_dir(res_dir)
    empty_resilience_dir(res_dir)

def create_resilience_dir(res_dir):
    try:
        os.mkdir(res_dir)
    except Exception as e:
        print 'Warning: mkdir %s failed: %s' % (res_dir, e)

def delete_resilience_dir(res_dir):
    try:
        os.rmdir(res_dir)
    except Exception as e:
        print 'Warning: rmdir %s failed: %s' % (res_dir, e)

def empty_resilience_dir(res_dir):
    # if any files are in this directory, remove them
    for f in os.listdir(res_dir):
        path = os.path.join(res_dir, f)
        try:
            os.remove(path)
        except Exception as e:
            print 'Warning: remove %s failed: %s' % (path, e)

def clean_resilience_path(res_dir):
    os.write(os.open('/dev/tty', os.WRONLY|os.APPEND), "clean %s" % res_dir)
    empty_resilience_dir(res_dir)
    delete_resilience_dir(res_dir)


def is_address_available(host, port):
    """
    Test whether a (host, port) pair is free
    """
    try:
        s = socket.socket()
        s.bind((host, port))
        s.close()
        return True
    except:
        return False


class PipelineTestError(Exception):
    pass


def get_port_values(num=1, host='127.0.0.1', base_port=20000):
    """
    Get the requested number (default: 1) of free ports for a given host
    (default: '127.0.0.1'), starting from base_port (default: 20000).
    """

    ports = []

    # Select source listener ports
    while len(ports) < num:
        if is_address_available(host, base_port):
            ports.append(base_port)
        base_port += 1
    return ports


BASE_COMMAND = r'''{command} \
    --in {inputs} \
    --out {outputs} \
    --metrics {host}:{metrics_port} \
    --control {host}:{control_port} \
    --resilience-dir {res_dir} \
    --name {{name}} \
    {{initializer_block}} \
    {{worker_block}} \
    {{join_block}} \
    {{spike_block}} \
    {{alt_block}} \
    --ponythreads=1 \
    --ponypinasio \
    --ponynoblock'''
INITIALIZER_CMD = r'''{worker_count} \
    --data {host}:{data_port} \
    --external {host}:{external_port} \
    --cluster-initializer'''
WORKER_CMD = r'''--my-control {host}:{control_port} \
    --my-data {host}:{data_port}'''
JOIN_CMD = r'''--join {host}:{control_port} \
    {worker_count}'''
WORKER_COUNT_CMD = r'''--worker-count {worker_count}'''
SPIKE_CMD = r'''--spike-drop \
    {prob} \
    {margin} \
    {seed}'''
SPIKE_SEED = r'''--spike-seed {seed}'''
SPIKE_PROB = r'''--spike-prob {prob}'''
SPIKE_MARGIN = r'''--spike-margin {margin}'''


def start_runners(runners, command, host, inputs, outputs, metrics_port,
                  control_port, external_port, data_port, res_dir, workers,
                  worker_ports=[], alt_block=None, alt_func=lambda x: False,
                  spikes={}):
    cmd_stub = BASE_COMMAND.format(command=command,
                                   host=host,
                                   inputs=inputs,
                                   outputs=outputs,
                                   metrics_port=metrics_port,
                                   control_port=control_port,
                                   res_dir=res_dir)

    # for each worker, assign `name` and `cluster-initializer` values
    if workers < 1:
        raise PipelineTestError("workers must be 1 or more")
    x = 0
    if x in spikes:
        logging.info("Enabling spike for initializer")
        sc = spikes[x]
        spike_block = SPIKE_CMD.format(
            prob=SPIKE_PROB.format(prob=sc.probability),
            margin=SPIKE_MARGIN.format(margin=sc.margin),
            seed=SPIKE_SEED.format(seed=sc.seed) if sc.seed else '')
    else:
        spike_block = ''
    cmd = cmd_stub.format(
        name='initializer',
        initializer_block=INITIALIZER_CMD.format(
            worker_count=WORKER_COUNT_CMD.format(worker_count=workers),
            data_port=data_port,
            external_port=external_port,
            host=host),
        worker_block='',
        join_block='',
        alt_block=alt_block if alt_func(x) else '',
        spike_block=spike_block)
    runners.append(Runner(cmd_string=cmd, name='initializer'))
    for x in range(1, workers):
        if x in spikes:
            logging.info("Enabling spike for worker{}".format(x))
            sc = spikes[x]
            spike_block = SPIKE_CMD.format(
                prob=SPIKE_PROB.format(prob=sc.probability),
                margin=SPIKE_MARGIN.format(margin=sc.margin),
                seed=SPIKE_SEED.format(seed=sc.seed) if sc.seed else '')
        else:
            spike_block = ''
        cmd = cmd_stub.format(name='worker{}'.format(x),
                              initializer_block='',
                              worker_block=WORKER_CMD.format(
                                  host=host,
                                  control_port=worker_ports[x-1][0],
                                  data_port=worker_ports[x-1][1]),
                              join_block='',
                              alt_block=alt_block if alt_func(x) else '',
                              spike_block=spike_block)
        runners.append(Runner(cmd_string=cmd,
                              name='worker{}'.format(x)))

    # start the workers, 50ms apart
    for idx, r in enumerate(runners):
        r.start()
        time.sleep(0.05)

        # check the runners haven't exited with any errors
        try:
            assert(r.is_alive())
        except Exception as err:
            stdout = r.get_output()
            raise PipelineTestError(
                    "Runner %d of %d has exited with an error: "
                    "\n---\n%s" % (idx+1, len(runners), stdout))
        try:
            assert(r.error is None)
        except Exception as err:
            raise PipelineTestError(
                    "Runner %d of %d has exited with an error: "
                    "\n---\n%s" % (idx+1, len(runners), r.error))


def add_runner(runners, command, host, inputs, outputs, metrics_port,
               control_port, external_port, data_port, res_dir, workers,
               my_control_port, my_data_port,
               alt_block=None, alt_func=lambda x: False, spikes={}):
    cmd_stub = BASE_COMMAND.format(command=command,
                                   host=host,
                                   inputs=inputs,
                                   outputs=outputs,
                                   metrics_port=metrics_port,
                                   control_port=control_port,
                                   res_dir=res_dir)

    # Test that the new worker *can* join
    if len(runners) < 1:
        raise PipelineTestError("There must be at least 1 worker to join!")

    if not any(r.is_alive() for r in runners):
        raise PipelineTestError("There must be at least 1 live worker to "
                                "join!")

    x = len(runners)
    if x in spikes:
        logging.info("Enabling spike for joining worker{}".format(x))
        sc = spikes[x]
        spike_block = SPIKE_CMD.format(
            prob=SPIKE_PROB.format(sc.probability),
            margin=SPIKE_MARGIN.format(sc.margin),
            seed=SPIKE_SEED.format(sc.seed) if sc.seed else '')
    else:
        spike_block = ''

    cmd = cmd_stub.format(name='worker{}'.format(x),
                          initializer_block='',
                          worker_block=WORKER_CMD.format(
                              host=host,
                              control_port=my_control_port,
                              data_port=my_data_port),
                          join_block=JOIN_CMD.format(
                              host=host,
                              control_port=control_port,
                              worker_count=(WORKER_COUNT_CMD.format(
                                  worker_count=workers) if workers else '')),
                          alt_block=alt_block if alt_func(x) else '',
                          spike_block=spike_block)
    runner = Runner(cmd_string=cmd,
                    name='worker{}'.format(x))
    runners.append(runner)

    # start the new worker
    runner.start()
    time.sleep(0.05)

    # check the runner hasn't exited with any errors
    try:
        assert(runner.is_alive())
    except Exception as err:
        stdout = runner.get_output()
        raise PipelineTestError(
                "Runner %d of %d has exited with an error: "
                "\n---\n%s" % (x+1, len(runners), stdout))
    try:
        assert(runner.error is None)
    except Exception as err:
        raise PipelineTestError(
                "Runner %d of %d has exited with an error: "
                "\n---\n%s" % (x+1, len(runners), r.error))


DEFAULT_SINK_STOP_TIMEOUT = 30
DEFAULT_RUNNER_JOIN_TIMEOUT = 30


def pipeline_test(generator, expected, command, workers=1, sources=1,
                  mode='framed', sinks=1, decoder=None, pre_processor=None,
                  batch_size=1, sink_expect=None,
                  sink_stop_timeout=DEFAULT_SINK_STOP_TIMEOUT,
                  sink_await=None, delay=None,
                  validate_file=None, giles_mode=False,
                  host='127.0.0.1', listen_attempts=1,
                  ready_timeout=30,
                  runner_join_timeout=DEFAULT_RUNNER_JOIN_TIMEOUT,
                  resilience_dir='/tmp/res-dir',
                  spikes={}):
    """
    Run a pipeline test without having to instrument everything
    yourself. This only works for 1-source, 1-sink topologies.

    Parameters:
    - `generator`: either a single data generator to use in a Sender's Reader,
        or a list of tuples of (generator, source_index) for use with
        multi-source applications. In the latter case, the senders are run
        sequentially, and the index is 0-based against the input addresses.
        the values in this set should be either strings or stringable. If they
        are custom data structures, they should already be encoded as strings.
    - `expectd`: the expect output set, to be compared against the received
        output. The data should be directly comparable to the decoded output.
    - `command`: the command to run each worker. Make sure to leave out the
        Wallaroo parameters: `--in`, `--out`, `--metrics`, `--data`,
        `--control`, `--external`, `--workers`, `--name`,
        `--cluster-initializer`, and `--ponynoblock`.
        These will be applied by the test setup utility.
    - `workers`: the number of workers to use in the test. Default: 1.
    - `sources`: the number of sources in the application. Default: 1.
    - `mode`: the decoding mode to use in the sink. Can be `'framed'` or
        `'newlines'`. Default: `'framed'`
    - `sinks`: the number of sinks to set up for the application. Default: 1.
    - `decoder`: an optional decoder to use for decoding the data from the
        sink. Default: None, assume data is strings.
    - `pre_processor`: an optional pre-processor to apply to the entire
        output set before comparing it against the expected data set.
        Default: None, assume output data is directly comparable.
    - `batch_size`: the batch size to use in the sender. Default: 1
    - `sink_expect`: the number of messages to expect at the sink. This allows
        directly relying on received output for timing control. Default: None
        Should be a list of `len(sinks)`.
    - `sink_await`: a list of (binary) strings to await for at the sink.
        Once all of the await values have been seen at the sink, the test may
        be stopped.
    - `sink_stop_timeout`: the timeout in seconds to use when awaiting an
        expected number of messages at the sink. Raise an error if timeout
        elapses. Default: 30
        Can be a number or a list of numbers of `len(sinks)`.
    - `delay`: If None, and `sink_expect` is also None, the pipeline test
        will wait until metrics messages have a 0 throughput or have stopped
        arriving. If set to a number > 0, the minimum delay in seconds to
        wait after data sending has completed before checking the sink's
        data. Default: None.
    - `validate_file`: save sink data to a file to be validated by an external
        process.
    - `giles_mode`: if True, include a 64-bit timestamp between the length
        header and the payload when saving sink data to file. This is a
        backward compatibility mode for validators that expected
        giles-receiver format.
    - `host`: the network host address to use in workers, senders, and
        receivers. Default '127.0.0.1'
    - `listen_attempts`: attempt to start an applicatin listening on ports
        that are provided by the system. After `listen_attempts` fail, raise
        an appropriate error. For tests that experience TCP_WAIT related
        errors, this value should be set higher than 1.
        Default 1.
    - `ready_timeout`: number of seconds before an error is raised if the
        application does not report as ready. Default 30
    - `runner_join_timeout`: the timeout in seconds to use when waiting for
      the runners to exit cleanly. If the timeout is exceeded, the runners
      are killed and an error is raised.
    - `resilience_dir`: The directory where resilience file are kept. This
        path will be cleaned up before and after each run.
    - `spikes`: A dict of 3-tuples with the worker index as its key, and
        the spike parameters (probability, margin, seed) as its value.

    `expected` and the processed sink(s) data should be directly equatable.
    The test fails if they fail an equality assertion.
    If multiple sinks are used, then expected should match the flattened
    list of procssed sinks` data.
    e.g. if there are 2 sinks with the data [1,1,1] and [2,2,2] respectively,
    then expected should be [1,1,1,2,2,2].
    """

    setup_resilience_path(resilience_dir)
    runners = []
    try:
        # Create sinks, metrics
        metrics = Metrics(host)

        # Start sinks and metrics, and get their connection info
        num_sinks = sinks
        if sink_expect is not None:
            if not isinstance(sink_expect, (list, tuple)):
                sink_expect = [sink_expect for x in range(num_sinks)]
        elif sink_await is not None:
            if len(sink_await) != num_sinks:
                sink_await = [sink_await[:] for x in range(num_sinks)]
        outputs = []
        sinks = []
        for x in range(num_sinks):
            sink = Sink(host, mode=mode)
            sink.start()
            if sink.err is not None:
                raise sink.err
            sink_host, sink_port = sink.get_connection_info()
            sinks.append(sink)
            outputs.append('{}:{}'.format(sink_host, sink_port))
        outputs = ','.join(outputs)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()

        # Make up to $(listener-attempts) to get application source listener
        # ports and start the application. If all attempts fail, fail with the
        # last attempt's output.
        runners_err = None
        for attempt in range(1, listen_attempts + 1):
            logging.debug("Attempt #%d to start workers with random listen"
                          " ports..." % attempt)
            try:
                # Number of ports:
                #             sources
                #           + 3 for initializer [control, data, external]
                #           + 2 * (workers - 1) [(my_control, my_data) for
                #                                each remaining worker]
                num_ports = sources + 3 + (2 * (workers - 1))
                ports = get_port_values(num=num_ports, host=host)
                (input_ports, (control_port, data_port, external_port),
                 worker_ports) = (ports[:sources],
                                  ports[sources:sources+3],
                                  zip(ports[-(2*(workers-1)):][::2],
                                      ports[-(2*(workers-1)):][1::2]))
                inputs = ','.join(['{}:{}'.format(host, p) for p in
                                   input_ports])
                start_runners(runners, command, host, inputs, outputs,
                              metrics_port, control_port, external_port,
                              data_port, resilience_dir, workers,
                              worker_ports, spikes=spikes)
                break
            except PipelineTestError as err:
                # terminate runners, prepare to retry
                for r in runners:
                    r.stop()
                raise err
                runners = []
                runners_err = err
        else:
            if runners_err is not None:
                logging.error("Failed to start runners after %d attempts" %
                              listen_attempts)
                raise runners_err

        # Wait until initializer reports ready
        runner_ready_checker = RunnerReadyChecker(runners, ready_timeout)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # Create senders
        senders = []
        if not isinstance(generator, list):
            generator = [(generator, 0)]
        for gen, idx in generator:
            reader = Reader(gen)
            sender = Sender(host, input_ports[idx], reader,
                            batch_size=batch_size)
            senders.append(sender)

        # start each sender and await its completion before startin the next
        for sender in senders:
            sender.start()
            sender.join()
            try:
                assert(sender.error is None)
            except Exception as err:
                raise PipelineTestError("Sender exited with the error:\n"
                                        "\n---START ERROR\n%s\n---END ERROR\n"
                                        "\nworker output is attached below.\n"
                                        "\n---START OUTPUT\n%s\n---END OUTPUT"
                                        % (sender.error,
                                           '\n---\n'.join([r.get_output()
                                                           for r in runners])))
        logging.debug('All senders completed sending.')
        # Use sink, metrics, or a timer to determine when to stop the
        # runners and sinks and begin validation
        if sink_expect:
            logging.debug('Waiting for {} messages at the sinks with a timeout'
                          ' of {} seconds'.format(sink_expect,
                                                  sink_stop_timeout))
            stoppers = []
            for sink, sink_expect_val in zip(sinks, sink_expect):
                stopper = SinkExpect(sink, sink_expect_val, sink_stop_timeout)
                stopper.start()
                stoppers.append(stopper)
            for stopper in stoppers:
                stopper.join()
                if stopper.error:
                    print '\nSinkStopper Error. Runner output below.\n'
                    for r in runners:
                        print '==='
                        print 'Runner: ', r.name
                        print '---'
                        print r.get_output()
                    raise stopper.error
        elif sink_await:
            logging.debug('Awaiting {} values at the sinks with a timeout of '
                          '{} seconds'.format(sum(map(len, sink_await)),
                                              sink_stop_timeout))
            stoppers = []
            for sink, sink_await_vals in zip(sinks, sink_await):
                stopper = SinkAwaitValue(sink, sink_await_vals,
                                         sink_stop_timeout)
                stopper.start()
                stoppers.append(stopper)
            for stopper in stoppers:
                stopper.join()
                if stopper.error:
                    print '\nSinkStopper Error. Runner output below.\n'
                    for r in runners:
                        print '==='
                        print 'Runner: ', r.name
                        print '---'
                        print r.get_output()
                    raise stopper.error

        elif delay:
            logging.debug('Waiting {} seconds before shutting off workers.'
                          .format(delay))
            time.sleep(delay)
        else:
            logging.debug('Waiting until metrics indicate no more traffic.')
            stopper = MetricsStopper(metrics, DEFAULT_SINK_EXPECT_TIMEOUT)
            stopper.start()
            stopper.join()
        logging.debug('Shutting down workers.')
        for r in runners:
            r.stop()
        logging.debug('Shutting down all sinks.')
        for s in sinks:
            s.stop()

        logging.debug('Begin validation phase...')
        # Use initializer's outputs to validate topology is set up correctly
        check_initializer = re.compile(r'([\w\d]+) worker topology')
        stdout = runners[0].get_output()
        try:
            m = check_initializer.search(stdout)
            assert(m is not None)
            topo_type = m.group(1)
            if topo_type.lower() == 'single':
                topo_type = 1
            else:
                topo_type = int(topo_type)
            assert(workers == topo_type)
        except Exception as err:
            print 'runner output'
            print stdout
            raise err

        if validate_file:
            validation_files = validate_file.split(',')
            for sink, fp in zip(sinks, validation_files):
                sink.save(fp, giles_mode)
            return [(r.name, r.get_output()) for r in runners]

        else:  # compare expected to processed
            # Decode captured output from sink
            if decoder:
                if not isinstance(decoder, (list, tuple)):
                    decoder = [decoder for s in sinks]
                decoded = []
                for sink, decoder in zip(sinks, decoder):
                    decoded.append([])
                    for item in sink.data:
                        decoded[-1].append(decoder(item))
            else:
                decoded = [sink.data for sink in sinks]

            if pre_processor:
                processed = pre_processor(decoded)
            else:
                processed = decoded

            # Validate captured output against expected output
            if isinstance(expected, basestring):
                expected = io.BufferedReader(io.BytesIO(expected))
            if isinstance(expected, (file, io.BufferedReader)):
                if isinstance(processed, list):
                    bytesio = io.BytesIO()
                    for part in processed:
                        for p in part:
                            bytesio.write(p)
                    bytesio.seek(0)
                    processed = io.BufferedReader(bytesio)
                elif isinstance(processed, basestring):
                    processed = io.BufferedReader(io.BytesIO(processed))
                # compare 50 bytes at a time
                while True:
                    start_block = expected.tell()
                    proc = processed.read(50)
                    exp = expected.read(50)
                    if not proc and not exp:
                        break
                    try:
                        assert(exp == proc)
                    except:
                        raise AssertionError("Validation failed in bytes {}:{}"
                                             " of expected file. Expected {!r}"
                                             " but received {!r}.".format(
                                                 start_block,
                                                 expected.tell(),
                                                 exp,
                                                 proc))
            else:
                flattened = list(itertools.chain.from_iterable(processed))
                if mode == 'newlines':
                    # add newlines to expected
                    expected = ['{}\n'.format(e) for e in expected]
                try:
                    assert(expected == flattened)
                except:
                    raise AssertionError("Validation failed. Expected {!r} but"
                                         " received {!r}".format(expected,
                                                                 processed))
    finally:
        # clean up any remaining runner processes
        for r in runners:
            r.stop()
        # Wait on runners to finish waiting on their subprocesses to exit
        for r in runners:
            r.join(runner_join_timeout)
        alive = []
        for r in runners:
            if r.is_alive():
                alive.append(r)
        if alive:
            alive_names = ', '.join((r.name for r in alive))
            outputs = [(r.name, r.get_output()) for r in runners]
            outputs = '\n===\n'.join(('\n---\n'.join(t) for t in outputs))
            for a in alive:
                a.kill()
            raise PipelineTestError("Runners [{}] failed to exit cleanly after"
                                    " {} seconds.\n"
                                    "Runner outputs are attached below:"
                                    "\n===\n{}"
                                    .format(alive_names, runner_join_timeout,
                                            outputs))

    # Return runner names and outputs if try block didn't have a return
    return [(r.name, r.get_output()) for r in runners]
