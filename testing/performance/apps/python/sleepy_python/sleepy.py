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


import argparse
from enum import IntEnum
import struct
import time
import wallaroo


def application_setup(args):
    parse_delay(args)
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    nonce_source = wallaroo.TCPSourceConfig(in_host, in_port, nonce_decoder)
    ab = wallaroo.ApplicationBuilder("sleepy-python")
    ab.new_pipeline("Counting Sheep", nonce_source)
    ab.to(process_nonce)
    ab.to_state_partition(
            busy_sleep, DreamData, "dream-data",
            partition_function, partitions
        )
    ab.to_sink(out_host, out_port, ok_encoder)
    return ab.build()


@wallaroo.decoder(header_length=4, length_fmt=">I")
def nonce_decoder(bytes):
    """
    Ignore most of the data and just read a partition number off of the
    message.
    """
    return struct.unpack(">I", bytes)


@wallaroo.encoder
def ok_encoder(_):
    return "ok"


class DreamData(object):
    __slots__ = ('sheep')
    def __init__(self, last_bid=0.0, last_offer=0.0, should_reject_trades=True):
        self.sheep = 0


@wallaroo.computation(name="Forward nonce partition")
def process_nonce(partition):
    return partition


@wallaroo.computation(name="Count sheep")
def busy_sleep(data, state):
    delay(delay_ms)
    state.sheep += 1
    if state.sheep % 1000 == 0:
        return data


# Pick 60 because it has a lot of convenient factors
partitions = list(xrange(0,60))

def partition_function(n):
    return partitions[n % len(partitions)]


# Set by --delay_ms argument
delay_ms = 0

def parse_delay(args):
    parser = argparse.ArgumentParser(prog='')
    parser.add_argument('--delay_ms', type=int, default=0)
    a, _ = parser.parse_known_args(args)
    global delay_ms
    delay_ms = a.delay_ms

def delay(ms):
  if ms == 0:
    return
  t = time.time()
  c = 0
  s = ms / 1000.0
  while (t + s) > time.time():
    c = c + 1

