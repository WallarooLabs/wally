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


import pickle
import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    sequence_partitions = ['0', '1']
    ab = wallaroo.ApplicationBuilder("Sequence Window")
    ab.new_pipeline("Sequence Window",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to(maybe_one_to_many)
    ab.to_state_partition(observe_new_value, SequenceWindow,
                          "Sequence Window", partition,
                          sequence_partitions)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


@wallaroo.partition
def partition(data):
    return str(data % 2)


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


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    # Expecting a 64-bit unsigned int in big endian
    value = struct.unpack(">Q", bs)[0]
    return value


MAGIC_NUMBER = 12
@wallaroo.computation_multi(name="Maybe one to many")
def maybe_one_to_many(data):
    """
    Possibly one to many this message.

    The goal is to keep a continous sequence of incrementing U64s.
    Every Xth number, we will send that number plus the next two numbers as a
    "one to many" message. We then filter the next to numbers when we come to
    them. This allows for us to test with a "normal" sequence window test that
    both "1 to 1" and "1 to many" work correctly.
    """
    if data < MAGIC_NUMBER:
        return [data]
    mod_magic = data % MAGIC_NUMBER
    if mod_magic == 0:
        return [data, data + 1, data + 2]
    elif mod_magic == 1 or mod_magic == 2:
        return None
    else:
        return [data]


@wallaroo.state_computation(name="Observer New Value")
def observe_new_value(data, state):
    state.update(data)
    return (state.get_window(), True)


@wallaroo.encoder
def encoder(data):
    # data is a list of integers
    s = "[{}]".format(",".join(str(v) for v in data))
    return struct.pack(">L{}s".format(len(s)), len(s), s)
