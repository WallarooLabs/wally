#!/usr/bin/env python2

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


import random
import struct

fmt = '>HH{}'.format(10*'L')
def generate_messages(num_messages):
    with open('numbers.msg', 'wb') as f:
        for x in xrange(num_messages):
            f.write(struct.pack(fmt, 42, 10,
                                *[random.randrange(1000000) for x in
                                  xrange(10)]))


if __name__ == '__main__':
    import sys
    try:
        num_messages = int(sys.argv[1])
        generate_messages(num_messages)
    except:
        raise
