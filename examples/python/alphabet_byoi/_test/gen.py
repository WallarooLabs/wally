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


from json import dumps
from random import choice, randrange
from string import lowercase
from struct import pack

# Construct input data list, and total votes as a dict
expected = {}
data = []
for x in xrange(1000):
    c = choice(lowercase)
    v = randrange(1,10000)
    data.append(pack(">IsI",5, c, v))
    expected[c] = expected.get(c, 0) + v

with open("_test.txt", "wb") as fin:
    for v in data:
        fin.write(v)

with open("_expected.json", "wb") as fout:
    fout.write(dumps(expected))
