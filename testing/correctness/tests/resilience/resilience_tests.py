#
# Copyright 2018 The Wallaroo Authors.
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

from resilience import (Crash,
                        Grow,
                        Recover,
                        Shrink,
                        Wait,
                        _test_resilience)
from test_creator import Creator

import sys
this = sys.modules[__name__]  # Passed to create_test

TC = Creator(this)


# TODO:
# - [x] Figure out issue with sender unable to connect
# - [x] Add test code generator
# - [ ] add: AddSource operation (and logic to validate)
# - [x] background crash detector with notifier-short-circuit capability
#       to eliminate timeout periods when a test fails due to crashed workers
# - [x] Clean out dev debug logs


CMD_PONY = 'multi_partition_detector --depth 1 --gen-source --run-with-resilience'
CMD_PYTHON = 'machida --application-module multi_partition_detector --depth 1 --gen-source --run-with-resilience'
CMD_PYTHON3 = 'machida3 --application-module multi_partition_detector --depth 1 --gen-source --run-with-resilience'

APIS = {'pony': CMD_PONY, 'python': CMD_PYTHON, 'python3': CMD_PYTHON3}


##############
# Test spec(s)
##############

RESILIENCE_TEST_NAME_FMT = 'test_resilience_{api}_{ops}'

##################
# Resilience Tests
##################

RESILIENCE_SEQS = [
    # wait, grow1, wait, shrink1, wait, crash2, wait, recover
    [Wait(2), Grow(1), Wait(2), Shrink(1), Wait(2), Crash(2),
     Wait(2), Recover(2), Wait(5)],

    # crash1, recover1
    [Wait(2), Crash(1), Wait(2), Recover(1), Wait(5)],

    # crash2, recover2
    [Wait(2), Crash(2), Wait(2), Recover(2), Wait(5)]]

# Generate resilience test functions for each api, for each of the op seqs
for api, cmd in APIS.items():
    for ops in RESILIENCE_SEQS:
        TC.create(RESILIENCE_TEST_NAME_FMT, api, cmd, ops,
                  sources=0)



print(globals())
print()

#############
# Fixed Tests
#############

# def test_grow1_wait2_shrink1_wait_2_times_ten():
#     command = 'multi_partition_detector --depth 1 --gen-source'
#     ops = [Wait(2), Grow(1), Wait(2), Shrink(1), Wait(2)]
#     _test_resilience(command, ops, validate_output=True, cycles=10, sources=0)


# The following tests only works if multi_partition_detector is compiled
# with -D allow-invalid-state
#def test_continuous_sending_crash2_wait2_recover2():
#    command = 'multi_partition_detector --depth 1'
#    ops = [Crash(2, pause=False), Wait(2), Recover(2, resume=False)]
#    _test_resilience(command, ops, validate_output=False)
