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


parser = argparse.ArgumentParser("Alerts Windowed validator")
parser.add_argument("--output", type=argparse.FileType("rb"),
                    help="The output file of the application.")
parser.add_argument("--window-type", default="tumbling",
                    choices=["tumbling", "sliding", "counting"])
args = parser.parse_args()

f = args.output
windows = {}
while True:
    header_bytes = f.read(4)
    if not header_bytes:
        break
    header = struct.unpack('>I', header_bytes)[0]
    payload = f.read(header)
    assert(len(payload) > 0)
    obj = loads(payload.decode())  # Python3.5/json needs a string
    windows.setdefault(obj['key'], {}).setdefault(obj['ts'], []).append(obj['value'])

# flatten windows to sequences
sequences = {}
for k in windows.keys():
    for w_key in sorted(windows[k].keys()):
        win = windows[k][w_key]
        if not (win == sorted(win)):
            assert(False), ("Out of order violation for key: {}, w_key: {}, "
                            "window: {}, sorted: {}"
                            .format(k, w_key, win, sorted(win)))
        sequences.setdefault(k, []).extend(win)


if args.window_type == 'sliding':
    for k, v in sequences.items():
        processed = sorted(list(set(v)))
        size = processed[-1] - processed[0] + 1 # Assumption: processed is a natural sequence

        #!@
        if len(processed) != size:
            print("!@ GAP IN PROCESSED FOR KEY " + k)
            print("processed = {} size = {} ".format(processed, size))
            old = processed[0]
            for i in range(1, len(processed)):
                if processed[i] != old + 1:
                    print("!@ -- ", old, " followed by ", processed[i])
                old = processed[i]

        assert(len(processed) == size), "Expect: sorted unique window elements form a subsegement of the natural sequence but for key {}".format(k)
    for k in sorted(windows.keys(), key=lambda k: int(k.replace('key_',''))):
        # Check that for each window, there are at most 2 duplicates per item
        # i.e. the duplicates are plausibly caused by the sub window overlap,
        # rather than by output duplications due to other factors
        subwindows = sorted(windows[k].keys())
        for i in range(len(subwindows)-1):
            counter = Counter(windows[k][subwindows[i]] +
                              windows[k][subwindows[i+1]])
            most_common = counter.most_common(3)
            assert(len(most_common) > 0)
            for key, count in most_common:
                assert(count in (1,2))

# Regardless of window type, check sequentialty:
# 1. increments are always at +1 size
# 2. rewinds are allowed at arbitrary size
for key in sequences:
    assert(sequences[key])
    old = sequences[key][0]
    for v in sequences[key][1:]:
        #!@
        if not ((v == old + 1) or (v <= old)):
            print("!@ Old for key " + key + ": " + str(old))
            print("!@ Cur for key " + key + ": " + str(v))
            print("old = {}".format(old))
            print("sequences[key] = {}".format(sequences[key]))
        assert((v == old + 1) or (v <= old))
        old = v
