import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit")
    ab.new_pipeline("Celsius Conversion",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to(Multiply)
    ab.to(Add)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
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
