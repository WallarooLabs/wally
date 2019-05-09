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
import struct


class OrderError(Exception):
    pass


def validate_window(window):
    assert(win == sorted(win)), ("Out of order violation for key: {}, "
                                 "w_key: {}, window: {}, sorted: {}"
                                 .format(k, w_key, window, sorted(window)))



parser = argparse.ArgumentParser("Multi Partition Detector Validator")
parser.add_argument("--output", type=argparse.FileType("rb"), nargs='+',
                    help="The output file of the application.")
args = parser.parse_args()

files = args.output

sink_data = {}
for f in files:
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

# flatten windows to sequences, using only the tail of the window
# eg. [1, 1, 2, 3, ...]
sequences = {}
for fname, data in sink_data.items():
    for k in data.keys():
        for ts, win in data[k]:
            validate_window(win)
            sequences.setdefault(k, {}).setdefault(fname, []).append(win[-1])

# TODO:
# 1. per stream: identify contiguous segments, and verify each segment
#       within a stream, large skips indicate segment (due to autoscale)
#       and rollbacks are rollbacks
# 2. per key (across multiple streams, possibly)
#    - [ ] segment count per key <= ops count
#    - [ ] sorted + unique == range(1, max(key data)+1) -- natural sequence
assert(0)

# Check completeness
for k, v in sequences.items():
    processed = sorted(list(set(v)))
    size = processed[-1] - processed[0] + 1 # Assumption: processed is a natural sequence

    if len(processed) != size:
        old = processed[0]
        for i in range(1, len(processed)):
            if processed[i] != old + 1:
                err_msg = ("Found a gap in data received for key {!r}: {!r} "
                           "is followed by {!r}\n"
                           "This may be caused by a reordering of messages "
                           "or by a state consistency violation."
                           .format(k, old, processed[i]))
                raise OrderError(err_msg)
            old = processed[i]
    assert(len(processed) == size)


# check sequentialty:
# 1. increments are always at +1 size
# 2. rewinds are allowed at arbitrary size
for key in sequences:
    assert(sequences[key])
    old = sequences[key][0]
    for v in sequences[key][1:]:
        if not ((v == old + 1) or (v <= old)):
            print("!@ Old for key " + key + ": " + str(old))
            print("!@ Cur for key " + key + ": " + str(v))
        assert((v == old + 1) or (v <= old)), ("Sequentiality violation "
            "detected! (Key: {}, Old: {}, Current: {})"
            .format(key, old, v))
        old = v


# Check sliding window rule: any value appears at most twice across
# any pair of subsequent windows of the same key
for k in sorted(windows.keys(), key=lambda k: int(k.replace('key_',''))):
    for i in range(len(windows[k])-1):
        counter = Counter(windows[k][i][1] +
                          windows[k][i+1][1])
        most_common = counter.most_common(3)
        assert(len(most_common) > 0)
        for key, count in most_common:
            if key != 0:
                assert(count in (1,2))
