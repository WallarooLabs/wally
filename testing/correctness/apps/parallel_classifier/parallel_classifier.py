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
This is a test example that showcases the parallelization capabilites of
Wallaroo, by tagging every input message with the OS-level PID of the
worker that has processed the input.
"""

from collections import namedtuple
import struct
import wallaroo
import time
import os

PID=None

def application_setup(args):
    global PID
    PID=str(os.getpid())
    in_name, in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    inputs = wallaroo.source("App",
                    wallaroo.TCPSourceConfig(in_host, in_port, in_name,
                                             decode))

    pipeline = (inputs
      .to(classify)
      .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode)))

    return wallaroo.build_application("Parallel App", pipeline)


# @wallaroo.state_computation(name='Batch single entries, emit batchs', state=RowBatches)
# def batch_rows(row, row_buffer):
#     return (row_buffer.update_with(row), True)


@wallaroo.computation(name="Classify")
def classify(x):
    return str(x)+":"+PID


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode(bs):
    return bs


@wallaroo.encoder
def encode(thing):
    x = str(thing)
    return struct.pack('>I',len(x)) + x
