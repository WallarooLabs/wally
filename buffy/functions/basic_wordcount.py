#!/usr/bin/env python3

"""
Basic word count

Take in a sentence, output 1 message per word, with count

"""

from string import punctuation
from . import state

FUNC_NAME = "BasicWordcount"

def word_counts_to_messages(word_counts):
    for (word, count) in word_counts.items():
        yield "%s,%d" % (word, count)

def split_words(sentence):
    # split on lines and spaces, strip punctuation, and lowercase everything
    return (w for w in filter(lambda x: x != '',
                              (p.strip(punctuation) for p
                               in (word for fragments
                                   in (line.split() for line
                                       in sentence.splitlines())
                                   for word in fragments))))

def func(input):
    words = split_words(input)
    word_counts = {}
    for w in words:
        state.add('words', 1, w)
        word_counts[w] = state.get_record('words', w)

    return word_counts_to_messages(word_counts)

# TESTS #
def test_basic_wordcount():
    state.state = state.State()
    input = 'see spot run.'
    expected = ['see,1', 'spot,1', 'run,1']
    output = [x for x in func(input)]
    for x in expected:
        assert(output.index(x) >= 0)
    for x in output:
        assert(expected.index(x) >= 0)

    count = state.get_record('words', 'see')
    assert(count == 1)
    count = state.get_record('words', 'spot')
    assert(count == 1)
    count = state.get_record('words', 'run')
    assert(count == 1)

    input = 'run spot run'
    expected = ['spot,2', 'run,3']
    output = [x for x in func(input)]
    for x in expected:
        assert(output.index(x) >= 0)
    for x in output:
        assert(expected.index(x) >= 0)

    count = state.get_record('words', 'see')
    assert(count == 1)
    count = state.get_record('words', 'spot')
    assert(count == 2)
    count = state.get_record('words', 'run')
    assert(count == 3)
