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
    obj = loads(payload)
    windows.setdefault(obj['key'], {}).setdefault(obj['ts'], []).append(obj['value'])

# flatten windows to sequences
sequences = {}
for k in windows.keys():
    for w in sorted(windows[k].keys()):
        sequences.setdefault(k, []).extend(windows[k][w])

if args.window_type in ('tumbling', 'counting'):
    for k, v in sequences.items():
        expected = list(range(1, len(v) + 1))
        assert(v == expected), "Expect natural sequence"

else: # window_type == 'sliding'
    for k, v in sequences.items():
        processed = sorted(list(set(v)))
        expected = list(range(1, len(processed) + 1))
        # unique items are natural sequences per key:
        assert(processed == expected)
        # there should duplicates from the sliding:
        assert(len(v) > len(expected)), "Expect duplication in sliding windows"
    for k in windows.keys():
        # Check that for each window, there are at most 2 duplicates per item
        # e.g. the duplicates are plausibly caused by the sub window overlap,
        # rather than by output duplications due to other factors
        subwindows = sorted(windows[k].keys())
        for i in range(len(subwindows)-1):
            counter = Counter(windows[k][subwindows[i]] +
                              windows[k][subwindows[i+1]])
            assert(counter.most_common(1)[0][1] == 2)
