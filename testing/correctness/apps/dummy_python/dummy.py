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

    ab = wallaroo.ApplicationBuilder("Dummy")
    ab.new_pipeline("Dummy",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to_stateful(count, StateObject, "DummyState")
    ab.to_state_partition(count_partitioned, PartitionedStateObject,
                          "PartitionedDummyState", partition)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


@wallaroo.partition
def partition(data):
    return str(hash(data))

class StateObject(object):
    def __init__(self):
        self.val = 0

    def update(self, value):
        self.val = value
        return value

class PartitionedStateObject(object):
    def __init__(self):
        self.val = 0

    def update(self, value):
        self.val = value
        return value

@wallaroo.state_computation(name="Count State Updates")
def count(data, state):
    res = state.update(data)
    return (res, True)

@wallaroo.state_computation(name="Count Partitioned State Updates")
def count_partitioned(data, state):
    res = state.update(data)
    return (res, True)

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return bs

@wallaroo.encoder
def encoder(data):
    return bytes(data)
