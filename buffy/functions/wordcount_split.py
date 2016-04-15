#!/usr/bin/env python3

"""
Wordcount Split

Split a sentence into words and send each word as a message
"""

import itertools
from . import state

FUNC_NAME = "WordcountSplit"

def words_to_messages(words):
    for w in words:
        yield (w, w)

def split_words(sentence):
    # split on spaces, drop non-words
    return [w for w in filter(lambda x: x.isalpha(),
                              sentence.lower().split(' '))]

def func(input):
    words = split_words(input)

    return (words_to_messages(words))
