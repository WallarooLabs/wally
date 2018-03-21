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


def test_autoscale_pony_grow_by_1():
    autoscale_sequence(CMD_PONY, ops=[1], cycles=CYCLES)


def test_autoscale_pony_grow_by_1_grow_by_many():
    autoscale_sequence(CMD_PONY, ops=[1, 4], cycles=CYCLES)


def test_autoscale_pony_grow_by_1_shrink_by_1():
    autoscale_sequence(CMD_PONY, ops=[1,-1], cycles=CYCLES)


def test_autoscale_pony_grow_by_1_shrink_by_many():
    autoscale_sequence(CMD_PONY, ops=[1,-4], cycles=CYCLES)


def test_autoscale_pony_grow_by_many_grow_by_1():
    autoscale_sequence(CMD_PONY, ops=[4,1], cycles=CYCLES)


def test_autoscale_pony_grow_by_many():
    autoscale_sequence(CMD_PONY, ops=[4], cycles=CYCLES)


def test_autoscale_pony_grow_by_many_shrink_by_1():
    autoscale_sequence(CMD_PONY, ops=[4,-1], cycles=CYCLES)


def test_autoscale_pony_grow_by_many_shrink_by_many():
    autoscale_sequence(CMD_PONY, ops=[4,-4], cycles=CYCLES)


def test_autoscale_pony_shrink_by_1_grow_by_1():
    autoscale_sequence(CMD_PONY, ops=[-1,1], cycles=CYCLES)


def test_autoscale_pony_shrink_by_1_grow_by_many():
    autoscale_sequence(CMD_PONY, ops=[-1,4], cycles=CYCLES)


def test_autoscale_pony_shrink_by_1():
    autoscale_sequence(CMD_PONY, ops=[-1], cycles=CYCLES)


def test_autoscale_pony_shrink_by_1_shrink_by_many():
    autoscale_sequence(CMD_PONY, ops=[-1,-4], cycles=CYCLES)


def test_autoscale_pony_shrink_by_many_grow_by_1():
    autoscale_sequence(CMD_PONY, ops=[-4,1], cycles=CYCLES)


def test_autoscale_pony_shrink_by_many_grow_by_many():
    autoscale_sequence(CMD_PONY, ops=[-4,4], cycles=CYCLES)


def test_autoscale_pony_shrink_by_many_shrink_by_1():
    autoscale_sequence(CMD_PONY, ops=[-4,-1], cycles=CYCLES)


def test_autoscale_pony_shrink_by_many():
    autoscale_sequence(CMD_PONY, ops=[-4], cycles=CYCLES)


def test_autoscale_python_grow_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[1], cycles=CYCLES)


def test_autoscale_python_grow_by_1_grow_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[1,4], cycles=CYCLES)


def test_autoscale_python_grow_by_1_shrink_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[1,-1], cycles=CYCLES)


def test_autoscale_python_grow_by_1_shrink_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[1,-4], cycles=CYCLES)


def test_autoscale_python_grow_by_many_grow_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[4,1], cycles=CYCLES)


def test_autoscale_python_grow_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[4], cycles=CYCLES)


def test_autoscale_python_grow_by_many_shrink_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[4,-1], cycles=CYCLES)


def test_autoscale_python_grow_by_many_shrink_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[4,-4], cycles=CYCLES)


def test_autoscale_python_shrink_by_1_grow_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[-1,1], cycles=CYCLES)


def test_autoscale_python_shrink_by_1_grow_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[-1,4], cycles=CYCLES)


def test_autoscale_python_shrink_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[-1], cycles=CYCLES)


def test_autoscale_python_shrink_by_1_shrink_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[-1,-4], cycles=CYCLES)


def test_autoscale_python_shrink_by_many_grow_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[-4,1], cycles=CYCLES)


def test_autoscale_python_shrink_by_many_grow_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[-4,4], cycles=CYCLES)


def test_autoscale_python_shrink_by_many_shrink_by_1():
    autoscale_sequence(CMD_PYTHON, ops=[-4,-1], cycles=CYCLES)


def test_autoscale_python_shrink_by_many():
    autoscale_sequence(CMD_PYTHON, ops=[-4], cycles=CYCLES)
