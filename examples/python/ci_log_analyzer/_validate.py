#!/usr/bin/env python

# Copyright 2017-2026 The Wallaroo Authors.
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
import json
import sys


def validate(output_file):
    with open(output_file, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    if not lines:
        sys.stderr.write("No output alerts received\n")
        return False

    for line in lines:
        try:
            data = json.loads(line)
            assert "alert" in data
            assert "file" in data
            assert "test" in data
        except Exception as e:
            sys.stderr.write("Invalid alert payload: {}\nError: {}\n".format(line, e))
            return False

    print("Successfully validated {} CI log analyzer alerts.".format(len(lines)))
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate CI log analyzer output.")
    parser.add_argument("--output", dest="output", default="received.txt",
                        help="Path to output sink file.")
    args = parser.parse_args()

    if not validate(args.output):
        sys.exit(1)
