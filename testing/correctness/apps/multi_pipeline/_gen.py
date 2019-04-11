# Copyright 2019 The Wallaroo Authors.
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


import json
import struct


expected = {}
for k in (1,2):
    expected[k] = []
    with open("_test{}.msg".format(k), "wb") as f:
        for x in range(1, 1001):
            f.write(struct.pack('>III', 8, k, x))
            expected[k].append(x)
with open("_expected.json", "wb") as f:
    f.write(json.dumps(expected))
