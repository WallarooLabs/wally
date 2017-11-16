import struct
from enum import IntEnum
import re
import json

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Apache Log file analysis")
    ab.new_pipeline("convert",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to_stateful(Count(), CounterBuilder(), "status counter")
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
    return ab.build()


class LogLine(object):
    def __init__(self, text):
        self.text = text


class BoundaryMessage(object):
    pass


class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        if bs == 'END_OF_DAY':
            return BoundaryMessage()
        else:
            return LogLine(bs)


class CounterBuilder(object):
    def build(self):
        return Counter()


class Counter(object):
    def __init__(self):
        self.reset()

    def reset(self):
        self.current_batch = {}
        self.current_day = None

    def update(self, day, return_code):
        if self.current_day is None:
            self.current_day = day
        if self.current_day != day:
            raise
        self.current_batch[return_code] = self.current_batch.get(return_code, 0) + 1

    def get_counts(self):
        return self.current_batch


class Count(object):
    def __init__(self):
        self.day_re = re.compile('\[(.*)\]')
        self.code_re = re.compile('"GET [^\s]* HTTP/[12].[01]" ([0-9]+)')

    def name(self):
        return "count status"

    def determine_return_code(self, line):
        m = self.code_re.search(line)
        if m is not None:
            return m.group(1)

    def determine_day(self, line):
        m = self.day_re.search(line)
        if m is not None:
            return m.group(1).split(':')[0]

    def compute(self, data, state):
        if isinstance(data, BoundaryMessage):
            return self.process_batch(state)
        elif isinstance(data,  LogLine):
            return_code = self.determine_return_code(data.text)
            day = self.determine_day(data.text)
            state.update(day, return_code)
            return (None, True)
        else:
            raise

    def name(self):
        return "Count return codes"

    def process_batch(self, state):
        r = state.get_counts()
        state.reset()
        return (r, True)


class Encoder(object):
    def encode(self, data):
        s = json.dumps(data).encode('UTF-8')
        return struct.pack('>I{}s'.format(len(s)), len(s), s)
