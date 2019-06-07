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

from .base import Application
from .configurations import base_window_policy


class WindowDetector(Application):
    name = 'WindowDetector'
    command = 'window_detector'

    def __init__(self, config={}):
        super().__init__()
        self.sources = ['Detector']
        self.config = base_window_policy.copy()
        self.config.update(config)
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
    name = 'WindowDetector'
    command = 'machida3 --application-module window_detector'

    def __init__(self, config=base_window_policy):
        super().__init__()
        self.sources = ['Detector']
        self.config = config


class MultiPartitionDetector(Application):
    name = 'MultiPartitionDetector'
    command = 'multi_partition_detector'

    def __init__(self, config=base_window_policy):
        super().__init__()
        self.sources = ['Detector']
        self.config = config
