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

    ab = wallaroo.ApplicationBuilder("multi crash dedupe")
    ab.new_pipeline("multi crash dedupe",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to(multi)
    ab.to(crash_if_none)
    ab.to_stateful(dedupe, LastInt, "last int")
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return struct.unpack(">Q", bs)[0]


@wallaroo.computation_multi(name="Multi")
def multi(data):
    print("> Multi got: {}".format(data))
    m = data % 7
    if m == 0:
        return [data]
    elif m == 1:
        return [data, data]
    elif m == 2:
        return [data, None]
    elif m == 3:
        return [None, data]
    elif m == 4:
        return [None]
    elif m == 5:
        return [None, None]
    else:
        return None


@wallaroo.computation(name="Crash if None")
def crash_if_none(data):
    print("> Crash if None got: {}".format(data))
    if data is None:
        print("Got a None input value that should have been filtered. Terminating!")
        exit(1)
    return data


class LastInt(object):
    def __init__(self):
        self.v = -1

    def maybe_update(self, new):
        if new < self.v:
            print("Got an out of order value. Terminating!")
            exit(1)
        if new > self.v:
            self.v = new
            return True
        return False


@wallaroo.state_computation(name="Dedupe")
def dedupe(data, state):
    print("> Dedupe got: {}".format(data))
    should_save = state.maybe_update(data)
    return (data if should_save else None, should_save)


@wallaroo.encoder
def encoder(data):
    print("> Encoder got: {}".format(data))
    return ('{}\n'.format(data)).encode()
