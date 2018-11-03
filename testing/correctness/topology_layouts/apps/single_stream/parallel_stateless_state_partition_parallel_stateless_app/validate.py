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


parser = argparse.ArgumentParser('Parallel Stateless -> State Partition -> '
                                 'Parallel Stateless validator')
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

# Split on partition (mod 3)
processed = [[], [], []]
for c,m in received:
    processed[m % 3].append((c,m))
# Sort on max
processed2 = [sorted(p, key=lambda x: x[1]) for p in processed]
# Pick last one from each
processed3 = [p[-1] for p in processed2]

# We'll just repeat the compuation to derive the correct results:
maxes = [0, 0, 0]
counts = [0, 0, 0]
for v in range(1, args.n+1):
    v2 = v * 2  # double
    i = (v2 % 6)/2  # partition mod 6, then map (0,2,4) to (0,1,2)
    maxes[i] = v2/2   # set max for partition to max/2
    counts[i] += 1  # set count for partition

expected = [(counts[i], maxes[i]) for i in range(0,3)]


try:
    assert(expected == processed3)
    assert(args.n == len(received))
except Exception as e:
    print 'expected final output to be:\n', expected
    print 'but received:\n', received
    raise e
