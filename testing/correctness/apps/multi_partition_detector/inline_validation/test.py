#
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
#

from . import *

def test_increments_test():
    valid_cases = [
        [1],
        [1,2,3],
        [0,0,1],
        [0,1],
        [10,11,12,13]]

    invalid_cases = [
        [0],
        [0,2],
        [0,0,2],
        [1,2,3,5],
        [1,3,4,5]]

    for case in valid_cases:
        assert(increments_test(case) is True)

    for case in invalid_cases:
        assert(increments_test(case) is False)
