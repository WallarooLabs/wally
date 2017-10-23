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


fmt = '>IQ'
def decode(bs):
    return unpack(fmt, bs)[1]


parser = argparse.ArgumentParser('Parallel Stateless validator')
parser.add_argument('--output', type=argparse.FileType('rb'),
                    help="The output file of the application.")
parser.add_argument('--expected', type=argparse.FileType('r'),
                    help="A file containing the expected output.")
args = parser.parse_args()


chunk_size = calcsize(fmt)
received = []
while True:
    chunk = args.output.read(chunk_size)
    if not chunk:
        break
    received.append(decode(chunk))
processed = sorted(received)

expected = []
while True:
    chunk = args.expected.read(chunk_size)
    if not chunk:
        break
    expected.append(decode(chunk))


try:
    assert(expected == processed)
except Exception as e:
    print 'expected\n=='
    print expected
    print 'but received\n=='
    print processed
    raise e
