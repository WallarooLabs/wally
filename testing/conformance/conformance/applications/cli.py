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

import struct

from ..base import (Application,
                    update_dict)
from ..completes_when import data_in_sink_contains


##############
# CLI Tester #
##############
base_cli_policy = {
    'command_parameters': {},
    'workers': 1,
    'input_size': 10,
    }

class CLITesterBase(Application):
    INPUT_ITEMS=10
    sources = ['dummy']
    split_streams = False

    def __init__(self, config={}):
        super().__init__()
        self.config = base_cli_policy.copy()
        update_dict(self.config, config)
        self.workers = self.config['workers']
        self.input_size = self.config['input_size']
        self.values = [chr(x+65) for x in range(self.input_size)]
        self.await_values = [struct.pack('>I', len(v.encode())) + v.encode()
                             for v in self.values]

    def parse_output(self, v):
        return v  # no .decode()!

    def send_data(self):
        self.send(self.values)
        self.completes_when(data_in_sink_contains(self.await_values),
                            timeout=90)


class CLITesterPython2(CLITesterBase):
    name = 'python2_DummyCLITester'
    command = 'machida --application-module dummy'


class CLITesterPython3(CLITesterBase):
    name = 'python3_DummyCLITester'
    command = 'machida3 --application-module dummy'
