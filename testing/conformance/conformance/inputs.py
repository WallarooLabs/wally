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


out_of_order_ts = [{'ts': 1000, 'key': 'key', 'value': 2},
                   {'ts': 1001, 'key': 'key', 'value': 3},
                   {'ts': 1002, 'key': 'key', 'value': 4},
                   {'ts':   50, 'key': 'key', 'value': 1},
                   {'ts': 1003, 'key': 'key', 'value': 5}]
