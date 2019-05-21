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
from collections import Counter
from json import loads
import os
import struct


class OrderError(Exception):
    pass


def validate_stream(stream):
    # rules
    # 1. increments are either +1 or +n, n>1
    # 1.1. if +1, still same contiguous segment
    # 1.2. if +n,n>1, new segment
    # 2. decrements unbounded, by should only go down to floor.
    # 2.1. Floor is initially 0, and is set to the new value after each
    # decrement
    # 2.2. Decrements are part of a contiugous segment, but also imply a
    # rollback
    # output is: count of segments, count of rollbacks

    if len(stream) == 0:
        return (0, 0)
    elif len(stream) == 1:
        return (1, 0)

    a = stream[0]
    floor = a
    segments = 1
    rollbacks = 0

    for v in stream[1:]:
        diff = v-a
        if diff == 1:
            a = v
            continue
        if diff > 1:
            segments += 1
            a = v
            continue
        if diff < 1:
            rollbacks += 1
            a = v
            floor = v
            continue
    return (segments, rollbacks)


parser = argparse.ArgumentParser("Multi Partition Detector Validator")
parser.add_argument("--output", type=str,
                    help="The output directory of the application data.")
args = parser.parse_args()

# If output is file, strip it to base dir
output = args.output.split(',')[0]
if os.path.isfile(output):
    output_dir = os.path.dirname(output)
elif os.path.isdir(output):
    output_dir = output
else:
    raise ValueError("Output must be a path to the output dir, or a file "
            "within it from which the output dir can be derived.")


output_files = os.listdir(output_dir)
# Read sink data
sink_files = [open(os.path.join(output_dir, f), 'rb')
              for f in output_files if f.startswith('sink')]
ops_file = open(os.path.join(output_dir,
                [f for f in output_files if f.startswith('ops.log')][0]), 'rt')

sink_data = {}
for f in sink_files:
    windows = sink_data.setdefault(f.name, {})
    while True:
        header_bytes = f.read(4)
        if not header_bytes:
            break
        header = struct.unpack('>I', header_bytes)[0]
        payload = f.read(header)
        #print(payload)
        assert(len(payload) > 0)
        obj = loads(payload.decode())  # Python3.5/json needs a string
        windows.setdefault(obj['key'], []).append((float(obj['ts']),
                                                   obj['value']))

# Read ops data
ops = []
for line in ops_file.readlines():
    o = line.strip()
    if o:
        ops.append(o)

# flatten windows to sequences, using only the tail of the window
# eg. [1, 1, 2, 3, ...]
sequences = {}
for fname, data in sink_data.items():
    for k in data.keys():
        for ts, win in data[k]:
            assert(win == sorted(win)), ("Out of order violation for key: {}, "
                                         "ts: {}, window: {}, sorted: {}"
                                         .format(k, ts, win, sorted(win)))
            sequences.setdefault(k, {}).setdefault(fname, []).append(win[-1])

# TODO:
# 1. per stream: identify contiguous segments, and verify each segment
#       within a stream, large skips indicate segment (due to autoscale)
#       and rollbacks are rollbacks
key_stats = {}
for key, streams in sequences.items():
    stats = key_stats[key] = {'segments': 0, 'rollbacks': 0}
    for fname, stream in streams.items():
        segments, rollbacks = validate_stream(stream)
        stats['segments'] += segments
        stats['rollbacks'] += rollbacks
        segs = stats['segments'] + stats['rollbacks']
        # segment count per key <= ops count + 1
        assert( segs <= len(ops) + 1), (
                "Too many segments for key {!r}! {} segments with "
                "ops {!r}. Expect at most {}".format(key, segs, ops,
                                                     len(ops) + 1))

# Check completeness per key
for key, sequences in sequences.items():
    s = sorted(set([y for x in sequences.values() for y in x]))
    high =  max(s)
    assert(s == range(1, high+1)), ("Found an error in data for key: {!r}.\n"
            "Output is missing the values: {!r}"
            .format(key,
                    sorted(set(range(1, high+1)) - set(s))))
