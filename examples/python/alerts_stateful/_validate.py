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
from json import loads


parser = argparse.ArgumentParser("Alerts Windowed validator")
parser.add_argument("--output", type=argparse.FileType("rb"),
                    help="The output file of the application.")
args = parser.parse_args()

while True:
    line = args.output.readline().decode()
    if not line:
        break
    assert(line.startswith("Deposit Alert for") or
           line.startswith("Withdrawal Alert for"))
