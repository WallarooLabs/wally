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
