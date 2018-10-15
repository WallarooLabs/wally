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

CMD_PONY = 'multi_partition_detector --depth 1'
CMD_PYTHON = 'machida --application-module multi_partition_detector --depth 1'

APIS = {'pony': CMD_PONY, 'python': CMD_PYTHON}


##############
# Test spec(s)
##############

AUTOSCALE_TEST_NAME_FMT = 'test_autoscale_{api}_{ops}'

#################
# Autoscale tests
#################

OPS = [Grow(1), Grow(4), Shrink(1), Shrink(4)]

# Programmatically create the tests, do the name mangling, and place them
# in the global scope for pytest to find
for api, cmd in APIS.items():
    for o1 in OPS:
        for o2 in OPS:
            if o1 == o2:
                TC.create(AUTOSCALE_TEST_NAME_FMT, api, cmd, [o1])
            else:
                TC.create(AUTOSCALE_TEST_NAME_FMT, api, cmd,
                            [o1, Wait(2), o2])
