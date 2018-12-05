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
from json import loads
import struct


parser = argparse.ArgumentParser("Alerts Windowed validator")
parser.add_argument("--output", type=argparse.FileType("rb"),
                    help="The output file of the application.")
args = parser.parse_args()

f = args.output
sequences = {}
while True:
    header_bytes = f.read(4)
    if not header_bytes:
        break
    header = struct.unpack('>I', header_bytes)[0]
    payload = f.read(header)
    assert(len(payload) > 0)
    obj = loads(payload)
    sequences.setdefault(obj['key'], []).append(obj['value'])

for k, v in sequences.items():
    print("key: {}".format(k))
    print("values: {}".format(v))
    assert(v == range(1, len(v) + 1))
