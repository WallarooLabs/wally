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

import itertools


# This first import is required for integration harness and wallaroo lib
# imports to work (it does path mungling to ensure they're available)
import conformance

# Test specific imports
from conformance.applications.topology import (TopologyTesterPython2,
                                               TopologyTesterPython3)

# Topology tester components required for test generation
from topology_tester import (COMPS,
                             POST,
                             PRE)

from integration import clear_current_test

####################
# Generative Tests #
####################

# Test creator
import sys
THIS = sys.modules[__name__]  # Passed to create_test

def create_test(name, app, config):
    def f():
        with app(config) as test:
            test.start_senders()
            test.join_senders()
            test.sink_await()
            test.validate()

    f.__name__ = name
    f = clear_current_test(f)
    setattr(THIS, name, f)

APPS = [TopologyTesterPython2,
        TopologyTesterPython3]

####################
# Resilience Tests #
####################
SOURCE_TYPES = ['tcp']
SOURCE_NUMBERS = [1]
# Cluster sizes
SIZES = [1, 2, 3]
# Maximum topology depth
DEPTH = 3


# Create basis set of steps from fundamental components
# TODO: enable tests with POST computation modifiers (filter,multi)
#prods = list(itertools.product(PRE, COMPS, POST))
prods = list(itertools.product(PRE, COMPS))

# eliminate Nones from individual tuples
filtered = list(map(tuple, [filter(None, t) for t in prods]))
# sort by length of tuple, then alphabetical order of tuple members
basis_steps = list(sorted(filtered, key=lambda v: (len(v), v)))

# Create topology sequences
sequences = []
for steps in itertools.chain.from_iterable(
            (itertools.product(basis_steps, repeat=d)
             for d in range(1, DEPTH+1))):
                sequences.append((list(itertools.chain.from_iterable(steps))))

# Create tests for size and api combinations
tests_count = 0
test_combos = []
for size in SIZES:
    for app in APPS:
        for seq in sequences:
            create_test(
                app=app,
                name = 'test_topology_{app}_{size}_workers_{topo}'.format(
                    app = app.name,
                    size = size,
                    topo = '_'.join(seq)),
                config = {'topology': seq,
                          'workers': size})
