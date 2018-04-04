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
from struct import calcsize, unpack


parser = argparse.ArgumentParser("Alphabet validator")
parser.add_argument("--output", type=argparse.FileType("rb"),
                    help="The output file of the application")
parser.add_argument("--expected", type=argparse.FileType("rb"),
                    help=("A file containing the expected output"))
args = parser.parse_args()

header_fmt = ">I"
header_size = calcsize(header_fmt)

# Since order isn't identical in every run (multiple workers)
# we need to build a lookup set from expected, then ensure each
# received record is in it, and no expected records are left unmatched
received = set()
while True:
    header = args.output.read(header_size)
    if not header:
        break
    payload = args.output.read(unpack(header_fmt, header)[0])
    if not payload:
        break
    received.add(payload[:-8])

expected = set()
while True:
    header = args.expected.read(header_size)
    if not header:
        break
    payload = args.expected.read(unpack(header_fmt, header)[0])
    if not payload:
        break
    expected.add(payload[:-8])

in_ex_but_not_rec = expected - received
in_rec_but_not_ex = received - expected

try:
    assert(not in_ex_but_not_rec)
except:
    raise AssertionError("Not all expected records were received.")
try:
    assert(not in_rec_but_not_ex)
except:
    raise AssertionError("Not all received records were expected.")
