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
    # split on lines and spaces, strip punctuation, and lowercase everything
    return (w for w in filter(lambda x: x != '',
                              (p.lower().strip(punctuation) for p
                               in (word for fragments
                                   in (line.split() for line
                                       in sentence.splitlines())
                                   for word in fragments))))

def func(input):
    words = split_words(input)

    return (words_to_messages(words))

# TESTS #
def test_wordcount_split():
    expected = ["see", "spot", "run", "run", "spot", "run"]
    actual = func("see spot. run run spot run")

    for (e, (_, a)) in zip(expected, actual):
        assert(e == a)

