import pickle
import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Sequence Window")
    ab.new_pipeline("Sequence Window",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to_stateful(ObserveNewValue(), SequenceWindowStateBuilder(),
                   "Sequence Window")
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
    return ab.build()


def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


class SequenceWindowStateBuilder(object):
    def build(self):
        return SequenceWindow()


class SequenceWindow(object):
    def __init__(self):
        self.windows = [[0, 0, 0, 0], [0, 0, 0, 0]]

    def update(self, value):
        window = self.windows[value % 2]
        window.append(value)
        if len(window) > 4:
            window.pop(0)
        return list(window)


class Decoder(object):
    def header_length(self):
        print "header_length"
        return 4

    def payload_length(self, bs):
        print "payload_length"

        l = struct.unpack(">I", bs)[0]
        return l

    def decode(self, bs):
        print "decode"
        # Expecting a 64-bit unsigned int in big endian
        value = struct.unpack(">Q", bs)[0]
        print "decode: value:", value
        return value


class ObserveNewValue(object):
    def name(self):
        return "Observe New Value"

    def compute(self, data, state):
        print "Observe New Value"
        window = state.update(data)
        return (window, True)


class Encoder(object):
    def encode(self, data):
        # data is a list of integers
        s = str(data)
        return struct.pack('>L{}s'.format(len(s)), len(s), s)
