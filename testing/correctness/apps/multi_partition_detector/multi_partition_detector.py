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
import struct

import wallaroo

from inline_validation import increments_test


def application_setup(args):
    # Parse user options for --depth and --internal-source
    parser = argparse.ArgumentParser("Multi Partition Detector")
    parser.add_argument("--depth", type=int, default=1,
                    help="The depth of the detector topology")
    parser.add_argument("--gen-source", action='store_true',
                    help="Use an internal source for resilience tests")
    parser.add_argument("--partitions", type=int, default=40,
                    help="Number of partitions for use with internal source")
    pargs, _ = parser.parse_known_args(args)

    if pargs.gen_source:
        print("Using internal source generator")
        source = wallaroo.GenSourceConfig(MultiPartitionGenerator(pargs.partitions))
    else:
        print("Using TCP Source")
        in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
        source = wallaroo.TCPSourceConfig(in_host, in_port, decoder)

    p = wallaroo.source("Detector", source)
    for x in range(pargs.depth):
        p = p.key_by(extract_key)
        p = p.to(trace_id)
        p = p.key_by(extract_key)
        p = p.to(trace_window)

    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    p = p.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return wallaroo.build_application("Multi Partition Detector", p)


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
        last_value = v.value()
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
    def __init__(self, key, payload):
        self.key = key
        self.payload = payload

    def value(self):
        if isinstance(self.payload, Ring):
            return self.payload.value()
        elif isinstance(self.payload, int):
            return self.payload
        else:
            raise ValueError("Got an invalid payload value: {!r}. "
                             "Payload must be a Ring or an int."
                             .format(self.payload))

    def __str__(self):
        return "({},{})".format(self.key, str(self.payload))

    def window(self):
        if isinstance(self.payload, Ring):
            return self.payload
        raise ValueError("Payload is not a Window(Ring) type")


class Ring(object):
    """
    A simple, but not-efficient ring implementation with a fixed size of 4
    """
    def __init__(self, from_array=None):
        if from_array:
            self._array = from_array
        else:
            self._array = [0,0,0,0]

    def push(self, value):
        self._array.append(value)
        self._array.pop(0)

    def value(self):
        return self._array[-1]

    def clone_array(self):
        # Return a shallow copy of the current ring
        return list(self._array)

    def clone(self):
        return Ring(self.clone_array())

    def __str__(self):
        return "[{}]".format(",".join(map(str, self._array)))

    def __getitem__(self, key):
        return self._array[key]

    def __iter__(self):
        return self._array.__iter__()

    def __len__(self):
        return len(self._array)


class WindowState(object):
    def __init__(self):
        self._window = Ring()
        self.key = None

    def __str__(self):
        return "({},{})".format(self.key, str(self._window))

    def push(self, msg):
        # validate key matches
        if not self.key:
            self.key = msg.key
        else:
            if msg.key != self.key:
                raise KeyError("Error: trying to update the wrong partition. "
                               "State key is {} but message key is {}."
                               .format(self.key, msg.key))

        # update window
        self._window.push(msg.value())

        # validate new ring: Increments test
        increments_test(self._window.clone_array())

    def window(self):
        return self._window.clone()


@wallaroo.computation(name="TraceID")
def trace_id(msg):
    print("trace_id({})".format(msg))
    return Message(msg.key + ".TraceID", msg.value())


@wallaroo.state_computation(name="TraceWindow", state=WindowState)
def trace_window(msg, state):
    print("trace_window({}, {})".format(msg, state))
    state.push(msg)
    print("trace_window.updated: {}".format(state))
    return Message(msg.key + ".TraceWindow", state.window())


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    # Expecting a 64-bit unsigned int in big endian followed by a string
    val, key = struct.unpack(">Q", bs[:8])[0], bs[8:]
    key = key.decode("utf-8")  # python3 compat in downstream string concat
    return Message(key, val)


@wallaroo.encoder
def encoder(msg):
    s = (str(msg)).encode()
    return struct.pack(">I{}s".format(len(s)), len(s), s)
