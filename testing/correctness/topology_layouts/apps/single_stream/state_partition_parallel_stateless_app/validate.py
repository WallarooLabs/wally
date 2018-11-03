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


fmt = '>IQQ'
def decode(bs):
    return unpack(fmt, bs)[1:3]


parser = argparse.ArgumentParser('State Partition -> Parallel Stateless validator')
parser.add_argument('--output', type=argparse.FileType('rb'),
                    help="The output file of the application.")
parser.add_argument('--n', type=int,
                    help="The final number in the sequence from 1 to n.")
args = parser.parse_args()


chunk_size = calcsize(fmt)
received = []
while True:
    chunk = args.output.read(chunk_size)
    if not chunk:
        break
    received.append(decode(chunk))

# Sort on counts
processed = sorted(received, key=lambda x: x[1])  # sort on count
# Pick top 3 and sort on partition key (mod 6)
processed2 = sorted(processed[-3:], key=lambda x: x[1] % 6)

# We'll just repeat the compuation to derive the correct results:
maxes = [0, 0, 0]
counts = [0, 0, 0]
for v in range(1, args.n+1):
    i = v % 3  # partition mod 3
    maxes[i] = v*2   # set max for partition to double v
    counts[i] += 1  # set count for partition

expected = [(counts[i], maxes[i]) for i in range(0,3)]

try:
    assert(expected == processed2)
    assert(args.n == len(processed))
except Exception as e:
    print 'expected final sum to be:\n', expected
    print 'but received:\n', received
    raise e
