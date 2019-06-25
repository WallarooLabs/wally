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


import os


# This first import is required for integration harness and wallaroo lib
# imports to work (it does path mungling to ensure they're available)
import conformance

# Test specific imports
from conformance.applications.system_events import (MultiPartitionDetectorPony,
                                                    MultiPartitionDetectorPython2,
                                                    MultiPartitionDetectorPython3,
                                                    Grow,
                                                    Shrink,
                                                    Crash,
                                                    Recover,
                                                    Rotate,
                                                    Wait)


from integration import clear_current_test

# Example manual test:
#
# def test_grow1_shrink1():
#     conf = {}
#     # ResilienceTestBaseApplications provide their own test runner
#     # So we only need to give it a config and a sequence of operations
#     with MultiPartitionDetector(config=conf) as test:
#         test.run_test_sequence([Wait(1), Grow(1), Wait(1), Shrink(1), Wait(1)])

####################
# Generative Tests #
####################

# Test creator
import sys
THIS = sys.modules[__name__]  # Passed to create_test
RESILIENCE = os.environ.get("resilience", None)

def create_test(name, app, config, ops, require_resilience=False):
    if require_resilience and RESILIENCE != "on":
        return
    else:
        def f():
            with app(config, ops=ops) as test:
                test.run_test_sequence()
        f.__name__ = name
        f = clear_current_test(f)
        setattr(THIS, name, f)

APPS = [MultiPartitionDetectorPony,
        MultiPartitionDetectorPython2,
        MultiPartitionDetectorPython3]

####################
# Resilience Tests #
####################
SOURCE_TYPES = ['alo']
SOURCE_NUMBERS = [1]

RESILIENCE_SEQS = [
    # wait, grow1, wait, shrink1, wait, crash2, wait, recover
    [Wait(2), Grow(1), Wait(2), Shrink(1), Wait(2), Crash(2),
     Wait(2), Recover(2), Wait(5)],

    # crash1, recover1
    [Wait(2), Crash(1), Wait(2), Recover(1), Wait(5)],

    # crash2, recover2
    [Wait(2), Crash(2), Wait(2), Recover(2), Wait(5)],

    # Log rotate
    [Wait(2), Rotate(), Wait(2)],

    # Log rotate and crash
    [Wait(2), Rotate(), Wait(2), Crash(1), Wait(2), Recover(1), Wait(2)],
    ]


# Test generation - Resilience + Log rotation:
for app in APPS:
    for ops in RESILIENCE_SEQS:
        for src_type in SOURCE_TYPES:
            for src_num in SOURCE_NUMBERS:
                test_name = (
                    'test_resilience_{app}_{source_type}_{source_number}_{ops}'
                    .format(
                        app=app.name,
                        source_type=src_type,
                        source_number=src_num,
                        ops='_'.join((o.name().replace(':','')
                                      for o in ops))))
                create_test(
                    name = test_name,
                    app = app,
                    config = {'command_parameters': {'source': src_type},
                              'source_number': src_num},
                    ops = ops,
                    require_resilience=True)



#################
# Autoscale tests
#################

OPS = [Grow(1), Grow(4), Shrink(1), Shrink(4)]
SOURCE_TYPES = ['tcp', 'alo']
SOURCE_NUMBERS = [1]

# Programmatically create the tests, do the name mangling, and place them
# in the global scope for pytest to find
for app in APPS:
    for o1 in OPS:
        for o2 in OPS:
            if o1 == o2:
                ops = [o1]
            else:
                ops = [o1, Wait(2), o2]
            for src_type in SOURCE_TYPES:
                for src_num in SOURCE_NUMBERS:
                    test_name = (
                        'test_autoscale_{app}_{source_type}_{source_number}_{ops}'
                        .format(
                            app=app.name,
                            source_type=src_type,
                            source_number=src_num,
                            ops='_'.join((o.name().replace(':','')
                                          for o in ops))))
                    create_test(
                        name = test_name,
                        app = app,
                        config = {'command_parameters': {'source': src_type},
                                  'source_number': src_num},
                        ops = ops,
                        require_resilience=False)
