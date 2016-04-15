#!/usr/bin/env python3

"""
Basic word count

Take in a sentence, output 1 message per word, with count

"""

from . import state

FUNC_NAME = "BasicWordcount"

def word_counts_to_messages(word_counts):
    for (word, count) in word_counts.items():
        yield "%s,%d" % (word, count)

def split_words(sentence):
    # split on spaces, drop non-words
    return (w for w in filter(lambda x: x.isalpha(),
                              sentence.lower().split(' ')))

def func(input):
    words = split_words(input)
    word_counts = {}
    for w in words:
        state.add('words', 1, w)
        word_counts[w] = state.get_record('words', w)

    return word_counts_to_messages(word_counts)
