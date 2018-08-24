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

import pytest

def pause_for_user():

    # suspend input capture by py.test so user input can be recorded here
    capture_manager = pytest.config.pluginmanager.getplugin('capturemanager')
    capture_manager.suspendcapture(in_=True)

    answer = raw_input("Press Return to continue\n")

    # resume capture after question have been asked
    capture_manager.resumecapture()
