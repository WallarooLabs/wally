#
# Copyright 2018 The Wallaroo Authors.
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
#


import argparse
import json
import struct

import wallaroo


def application_setup(args):

    print("Using TCP Source")
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    source = wallaroo.TCPSourceConfig(in_host, in_port, decoder)

    p = wallaroo.source("tumbling time window", source)
    p = p.key_by(extract_key)
    p = p.to(trace_id)
    p = p.key_by(extract_key)
    p = p.to(wallaroo.range_windows(wallaroo.milliseconds(50))
             .over(Collect()))

    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    p = p.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return wallaroo.build_application("Tumbling Time Window Detector", p)


class MultiPartitionGenerator(object):
    """
    An internal message generator for use in resilience tests
    """
    def __init__(self, partitions=1):
        self.partitions = partitions

    def initial_value(self):
        return self.format_message(0,1)

    def apply(self, v):
        last_key = int(v.key)
        last_value = v.value
        if (last_key + 1) == self.partitions:
            next_value = last_value + 1
        else:
            next_value = last_value
        next_key = (last_key + 1) % self.partitions

        return self.format_message(next_key, next_value)

    def format_message(self, key, val):
        m = Message("{}".format(key), val)
        return m


@wallaroo.key_extractor
def extract_key(msg):
    return msg.key.split(".")[0]


class Message(object):
    def __init__(self, key, value):
        self.key = key
        self.value = value

    def __str__(self):
        return "({},{})".format(self.key, self.value)


@wallaroo.computation(name="TraceID")
def trace_id(msg):
    print("trace_id({})".format(msg))
    return Message(msg.key + ".TraceID", msg.value)


class Collect(wallaroo.Aggregation):
    def initial_accumulator(self):
        return []

    def update(self, msg, accumulator):
        # tag data key, then add it to accumulator
        accumulator.append(Message(msg.key + ".Collect", msg.value))

    def combine(self, accumulator1, accumulator2):
        return accumulator1 + accumulator2

    def output(self, key, accumulator):
        print(key, [str(m) for m in accumulator])
        keys = set(m.key for m in accumulator)
        values = tuple(m.value for m in accumulator)
        assert(len(keys) == 1)
        assert(keys.pop().split(".")[0] == key)
        return (key, values)


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    # Expecting a 64-bit unsigned int in big endian followed by a string
    val, key = struct.unpack(">Q", bs[:8])[0], bs[8:]
    key = key.decode("utf-8")  # python3 compat in downstream string concat
    return Message(key, val)


@wallaroo.encoder
def encoder(msg):
    s = json.dumps({'key': msg[0], 'values': msg[1]})
    return struct.pack(">I{}s".format(len(s)), len(s), s)
