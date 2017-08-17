import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Reverse Word")
    ab.new_pipeline("reverse", Decoder(),
                    wallaroo.TCPSourceConfig(in_host, in_port))
    ab.to(Reverse)
    ab.to_sink(Encoder(),
               wallaroo.TCPSinkConfig(out_host, out_port))
    return ab.build()


class Decoder(object):
    def header_length(self):
        print "header_length"
        return 4

    def payload_length(self, bs):
        print "payload_length", bs
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        print "decode", bs
        return bs.decode("utf-8")


class Reverse(object):
    def name(self):
        return "reverse"

    def compute(self, data):
        print "compute", data
        return data[::-1]


class Encoder(object):
    def encode(self, data):
        # data is a string
        print "encode", data
        return data + "\n"
