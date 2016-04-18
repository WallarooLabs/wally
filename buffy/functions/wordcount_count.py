#!/usr/bin/env python3

"""
Wordcount counter

count the occurences of words

"""

from . import state

FUNC_NAME = "WordcountCount"

def func(input):
    state.add('words', 1, input)

    return "%s,%d" % (input, state.get_record('words', input))

# TESTS #
def test_wordcount_count():
    state.state = state.State()
    assert(func("see") == "see,1")
    assert(func("spot") == "spot,1")
    assert(func("run") == "run,1")
    assert(func("run") == "run,2")
    assert(func("spot") == "spot,2")
    assert(func("run") == "run,3")

    count = state.get_record('words', 'see')
    assert(count == 1)
    count = state.get_record('words', 'spot')
    assert(count == 2)
    count = state.get_record('words', 'run')
    assert(count == 3)
