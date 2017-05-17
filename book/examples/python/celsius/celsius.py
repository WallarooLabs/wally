import struct

import wallaroo


def application_setup(args):
    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit")
    ab.new_pipeline("convert", Decoder())
    ab.to(Multiply)
    ab.to(Add)
    ab.to_sink(Encoder())
    return ab.build()


class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        return struct.unpack('>f', bs)[0]


class Multiply(object):
    def name(self):
        return "multiply by 1.8"

    def compute(self, data):
        return data * 1.8


class Add(object):
    def name(self):
        return "add 32"

    def compute(self, data):
        return data + 32


class Encoder(object):
    def encode(self, data):
        # data is a float
        return struct.pack('>If', 4, data)
