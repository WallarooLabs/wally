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


import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Reverse Word")
    ab.new_pipeline("reverse",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to(Reverse)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
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
