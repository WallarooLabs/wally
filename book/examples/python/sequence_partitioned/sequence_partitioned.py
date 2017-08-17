import pickle
import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    print "args = {}".format(args)
    sequence_partitions = [0, 1]
    ab = wallaroo.ApplicationBuilder("Sequence Window")
    ab.new_pipeline("Sequence Window", Decoder(),
                    wallaroo.TCPSourceConfig(in_host, in_port))
    ab.to_state_partition(ObserveNewValue(), SequenceWindowStateBuilder(),
                          "Sequence Window", SequencePartitionFunction(),
                          sequence_partitions)
    ab.to_sink(Encoder(),
               wallaroo.TCPSinkConfig(out_host, out_port))
    return ab.build()


def serialize(obj):
    return pickle.dumps(obj)


def deserialize(bs):
    return pickle.loads(bs)


class SequencePartitionFunction(object):
    def partition(self, data):
        return data % 2


class SequenceWindowStateBuilder(object):
    def build(self):
        return SequenceWindow()


class SequenceWindow(object):
    def __init__(self):
        self.window = [0, 0, 0, 0]

    def update(self, value):
        self.window.append(value)
        if len(self.window) > 4:
            self.window.pop(0)

    def get_window(self):
        # Return a shallow copy of the current window
        return list(self.window)


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
        state.update(data)
        return (state.get_window(), True)


class Encoder(object):
    def encode(self, data):
        print "Encoder:encode: ", data
        # data is a list of integers
        s = str(data)
        return struct.pack('>L{}s'.format(len(s)), len(s), s)
