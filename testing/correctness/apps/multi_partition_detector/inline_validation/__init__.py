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

def increments_test(values):
    """
    Test that the values increment by 1, except for leading zeroes.
    """
    # if values size is less than 2, it isn't testable
    if len(values) < 1:
        return False
    if len(values) == 1:
        if values[0] == 1:
            return True
        else:
            return False

    # values > 1, do the test!
    prev = values[0]
    for cur in values[1:]:
        diff = cur - prev
        if diff == 0:
            if prev != 0:
                return false
            prev = cur
        elif diff != 1:
            return False
        else:
            prev = cur
    return True
