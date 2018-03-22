"""
How these tests are run:
Each test performs the sequence of autoscale operations described
by `ops` a `cycles` number of times. That means, for example, that
`ops=[2,-1], cycles=3` will result in a sequence of grow-by-2; shrink-by-1
performed 3 times in a row (or a total sequence of [2,-1,2,-1,2,-1]).

When a test fails, it will report the total sequence of ops that have occured
up until the failure.
For example, a failure in the 2nd op of the third cycle of the above example
will say it failed after the operations [2,-1,2,-1,2,-1].
"""


# set up basic logging
import logging
from integration import INFO2, set_logging
set_logging(name='autoscale_tests', level=INFO2,
            fmt='%(levelname)s - %(message)s')


from _autoscale_tests import autoscale_sequence


CMD_PONY = 'alphabet'
CMD_PYTHON = 'machida --application-module alphabet'
#CMD_PONY = 'alphabet27'
#CMD_PYTHON = 'machida --application-module alphabet27'

CYCLES=4
APIS = {'pony': CMD_PONY, 'python': CMD_PYTHON}

#
# Setup Tests
#

SETUP_TEST_NAME_FMT = 'test_setup_{api}_{size}_workers'
SIZES = range(10, 51, 10)


def create_setup_test(api, cmd, workers):
    """
    Create a setup test for a given `api` `cmd` with a cluster size `workers`
    """
    test_name = SETUP_TEST_NAME_FMT.format(api=api, size=workers)
    def f():
        autoscale_sequence(cmd, ops=[], cycles=1, initial=workers)
    f.func_name = test_name
    globals()[test_name] = f

# Programmatically create the tests, do the name mangling, and place them
# in the global scope for pytest to find
for api, cmd in APIS.items():
    for workers in SIZES:
        create_setup_test(api, cmd, workers)


#
# Autoscale tests
#

AUTOSCALE_TEST_NAME_FMT = 'test_autoscale_{api}_{ops}'
OPS = [1, 4, -1, -4]
OP_NAMES = {1: 'grow_by_1',
            4: 'grow_by_many',
            -1: 'shrink_by_1',
            -4: 'shrink_by_many'}


def create_autoscale_test(api, cmd, seq, cycles, initial=None):
    ops = '_'.join((OP_NAMES[o] for o in seq))
    test_name = AUTOSCALE_TEST_NAME_FMT.format(api=api, ops=ops)
    def f():
        autoscale_sequence(cmd, ops=seq, cycles=cycles, initial=initial)
    f.func_name = test_name
    globals()[test_name] = f


# Programmatically create the tests, do the name mangling, and place them
# in the global scope for pytest to find
for api, cmd in APIS.items():
    for o1 in OPS:
        for o2 in OPS:
            if o1 == o2:
                create_autoscale_test(api, cmd, [o1], CYCLES)
            else:
                create_autoscale_test(api, cmd, [o1, o2], CYCLES)
