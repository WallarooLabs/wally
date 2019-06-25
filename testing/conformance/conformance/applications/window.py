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
import logging
import math
from numbers import Number
import os
from random import Random as _Random
import re
import struct
import sys
import time

from ..__init__ import root  # absolute path for Wallaroo repo
from ..base import (Application,
                    update_dict)
from ..completes_when import (data_in_sink_contains,
                              data_in_sink_count_is)

from integration.cluster import runner_data_format
from integration.end_points import (ALOSender,
                                    ALOSequenceGenerator,
                                    MultiSequenceGenerator,
                                    Reader,
                                    Sender,
                                    sequence_generator)
from integration.errors import TimeoutError
from integration.external import (makedirs_if_not_exists,
                                  run_shell_cmd)
from integration.integration import json_keyval_extract


base_window_policy = {
    'command_parameters': {
                      'window-delay': 0,
                      'window-late-data-policy': 'drop',
                      'window-size': 1000,
                      'window-slide': 0,
                      'window-type': 'tumbling',
                      'decoder': 'json',
                      }}


class WindowDetector(Application):
    name = 'pony_WindowDetector'
    command = 'window_detector'
    sources = ['Detector']

    def __init__(self, config={}):
        super().__init__()
        self.config = base_window_policy.copy()
        update_dict(self.config, config)
        logging.info("Running {!r} with config {!r}".format(
            self.__class__.name, self.config))

    # Provide a function for iter_generator to use to serialise each item
    def serialise_input(self, v):
        return json.dumps(v).encode()

    def parse_output(self, bs):
        logging.debug('parse_output: {}'.format(repr(bs)))
        return json.loads(bs[4:].decode())['value']

    def collect(self):
        data = super().collect(None) # {'0': [...]}
        output = [self.parse_output(v) for v in data[0]]

        return output


class WindowDetectorPython3(Application):
    name = 'python3_WindowDetector'
    command = 'machida3 --application-module window_detector'
    sources = ['Detector']

    def __init__(self, config={}):
        super().__init__()
        self.config = base_multi_partition_detector_policy.copy()
        update_dict(self.config, config)
        logging.info("Running (!r} with config {!r}".format(
            self.__class__.name, self.config))

    # Provide a function for iter_generator to use to serialise each item
    def serialise_input(self, v):
        return json.dumps(v).encode()

    def parse_output(self, bs):
        logging.debug('parse_output: {}'.format(repr(bs)))
        return json.loads(bs[4:].decode())['value']

    def collect(self):
        data = super().collect(None) # {'0': [...]}
        output = [self.parse_output(v) for v in data[0]]

        return output
