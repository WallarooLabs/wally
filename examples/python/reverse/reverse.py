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

"""
This is an example application that receives strings as input and outputs the
reversed strings.
"""

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Reverse Word")
    ab.new_pipeline("reverse",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to(reverse)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return bs.decode("utf-8")


@wallaroo.computation(name="reverse")
def reverse(data):
    return data[::-1]


@wallaroo.encoder
def encoder(data):
    # data is a string
    return (data + "\n").encode()
