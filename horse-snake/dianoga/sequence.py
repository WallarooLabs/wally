import struct

import wallaroo

def test_python():
    return "hello python"


def application_setup(args):
    ab = wallaroo.ApplicationBuilder("Sequence Window")
    ab.new_pipeline("Sequence Window", Decoder())
    ab.to_stateful(ObserveNewValue(), SequenceWindowStateBuilder(), "Sequence Window")
    ab.to_sink(Encoder())
    return ab.build()


class SequenceWindowStateBuilder(object):
    def build(self):
        return SequenceWindow()


class SequenceWindow(object):
    def __init__(self):
        self.window = [0,0,0,0]

    def update(self, value):
        self.window.append(value)
        if len(self.window) > 4:
            self.window.pop(0)

    def get_window(self):
        # create a shallow copy of the current window
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
        return state.get_window()


class Encoder(object):
    def encode(self, data):
        print "Encoder:encode: ", data
        # data is a list of integers
        return str(data) + "\n"
