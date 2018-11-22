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
      .to(pass_through)
      .to(count)
      .key_by(partition)
      .to(count_partitioned)
      .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder)))
    return wallaroo.build_application("Dummy", pipeline)



@wallaroo.key_extractor
def partition(data):
    print("partition({!r})".format(data))
    return str(hash(data))


class StateObject(object):
    def __init__(self):
        self.val = 0

    def update(self, value):
        print("StateObject.update({!r})".format(value))
        self.val = value
        return self.val



class PartitionedStateObject(object):
    def __init__(self):
        self.val = 0

    def update(self, value):
        print("PartitionedStateObject.update({!r})".format(value))
        self.val = value
        return self.val


@wallaroo.computation(name="Pass through")
def pass_through(data):
    print("pass_through({!r})".format(data))
    return data


@wallaroo.state_computation(name="Count State Updates", state=StateObject)
def count(data, state):
    print("count({!r},{!r})".format(data, state))
    res = state.update(data)
    return res


@wallaroo.state_computation(name="Count Partitioned State Updates", state=PartitionedStateObject)
def count_partitioned(data, state):
    print("count_partitioned({!r},{!r})".format(data, state))
    res = state.update(data)
    return res


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    print("decoder({!r})".format(bs))
    return bs



@wallaroo.encoder
def encoder(data):
    print("encoder({!r})".format(data))
    return struct.pack('>I', len(data)) + data
