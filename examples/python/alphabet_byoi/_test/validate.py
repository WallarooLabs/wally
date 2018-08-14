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
from struct import calcsize, unpack

def decoder(bs):
    parts = [v.strip() for v in bs.split("=>")]
    return (parts[0], int(parts[1]))

def pre_processor(decoded):
    totals = {}
    for c, v in decoded:
        totals[c] = v
    return totals

parser = argparse.ArgumentParser("Alphabet validator")
parser.add_argument("--output", type=argparse.FileType("rb"),
                    help="The output file of the application.")
parser.add_argument("--expected", type=argparse.FileType("r"),
                    help=("A file containing the expected final vote tally as "
                          "JSON serialised dict."))
args = parser.parse_args()

decoded = []
while True:
    chunk = args.output.readline()
    chunk = chunk.strip()
    if not chunk:
        break
    decoded.append(decoder(chunk))
processed = pre_processor(decoded)

expected = loads(args.expected.read())
for k in expected.keys():
    s_key = str(k)
    expected[s_key] = expected.pop(k)

assert(expected == processed)
