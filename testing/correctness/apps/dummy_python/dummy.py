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

    pipeline = (wallaroo.source("Dummy",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
      .to(count)
      .key_by(partition)
      .to(count_partitioned)
      .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder)))
    ba = wallaroo.build_application("Dummy", pipeline)
    print("application setuped!", ba)
    return ba



@wallaroo.key_extractor
def partition(data):
    print("partition({})".format(data))
    return str(hash(data))


class StateObject(object):
    def __init__(self):
        self.val = 0

    def update(self, value):
        print("StateObject.update({})".format(value))
        self.val = value.encode()
        return self.val



class PartitionedStateObject(object):
    def __init__(self):
        self.val = 0

    def update(self, value):
        print("PartitionedStateObject.update({})".format(value))
        self.val = value.encode()
        return self.val



@wallaroo.state_computation(name="Count State Updates", state=StateObject)
def count(data, state):
    print("count({},{})".format(data, state))
    res = state.update(data)
    return (res, True)


@wallaroo.state_computation(name="Count Partitioned State Updates", state=PartitionedStateObject)
def count_partitioned(data, state):
    print("count_partitioned({},{})".format(data, state))
    res = state.update(data)
    return (res, True)


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    print("decoder({})".format(bs))
    return bs.encode()



@wallaroo.encoder
def encoder(data):
    print("encoder({})".format(data))
    return data.encode()
