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


# multi_partition_detector
APIS = {
    'pony': [
        {'app': 'multi_partition_detector',
         'cmd': 'multi_partition_detector --depth 1 --gen-source --run-with-resilience',
         'validation_cmd': None}],
    'python': [
        {'app': 'multi_partition_detector',
         'cmd': 'machida --application-module multi_partition_detector --depth 1 --gen-source --run-with-resilience',
         'validation_cmd': None},
        {'app': 'window_detector_tumbling',
         'cmd': 'machida --application-module window_detector --gen-source --window-type tumbling --window-delay 100 --run-with-resilience',
         'validation_cmd': 'python ../../apps/window_detector/_validate.py --window-type tumbling --output {out_file}'},
        {'app': 'window_detector_counting',
         'cmd': 'machida --application-module window_detector --gen-source --window-type counting --run-with-resilience',
         'validation_cmd': 'python ../../apps/window_detector/_validate.py --window-type counting --output {out_file}'},
        {'app': 'window_detector_sliding',
         'cmd': 'machida --application-module window_detector --gen-source --window-type sliding --window-delay 100 --run-with-resilience',
         'validation_cmd': 'python ../../apps/window_detector/_validate.py --window-type sliding --output {out_file}'}],
    'python3': [
        {'app': 'multi_partition_detector',
         'cmd': 'machida3 --application-module multi_partition_detector --depth 1 --gen-source --run-with-resilience',
         'validation_cmd': None},
        {'app': 'window_detector_tumbling',
         'cmd': 'machida3 --application-module window_detector --gen-source --window-type tumbling --window-delay 100 --run-with-resilience',
         'validation_cmd': 'python3 ../../apps/window_detector/_validate.py --window-type tumbling --output {out_file}'},
        {'app': 'window_detector_counting',
         'cmd': 'machida3 --application-module window_detector --gen-source --window-type counting --run-with-resilience',
         'validation_cmd': 'python3 ../../apps/window_detector/_validate.py --window-type counting --output {out_file}'},
        {'app': 'window_detector_sliding',
         'cmd': 'machida3 --application-module window_detector --gen-source --window-type sliding --window-delay 100 --run-with-resilience',
         'validation_cmd': 'python3 ../../apps/window_detector/_validate.py --window-type sliding --output {out_file}'}]}


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
    [Wait(2), Crash(2), Wait(2), Recover(2), Wait(5)]
    ]

# Generate resilience test functions for each api, for each of the op seqs
for api, group in APIS.items():
    for app in group:
        for ops in RESILIENCE_SEQS:
            TC.create(RESILIENCE_TEST_NAME_FMT,
                      '{}_{}'.format(api, app['app']),
                      app['cmd'], ops,
                      validation_cmd = app['validation_cmd'],
                      sources=0)




#############
# Fixed Tests
#############

# def test_grow1_wait2_shrink1_wait_2_times_ten():
#     command = 'multi_partition_detector --depth 1 --gen-source'
#     ops = [Wait(2), Grow(1), Wait(2), Shrink(1), Wait(2)]
#     _test_resilience(command, ops, cycles=10, sources=0)


# The following tests only works if multi_partition_detector is compiled
# with -D allow-invalid-state
#def test_continuous_sending_crash2_wait2_recover2():
#    command = 'multi_partition_detector --depth 1'
#    ops = [Crash(2, pause=False), Wait(2), Recover(2, resume=False)]
#    _test_resilience(command, ops, validation_cmd=False)
