# Copyright 2017 The Wallaroo Authors.
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

"""
This uses our dynamic-keyed word count example, modified to use Redis
as a source (multiple pubsub topics for text) and sink (counts as key-value
pairs).
"""

import string
import wallaroo
import wallaroo.experimental

import text_documents
import word_counts


def application_setup(args):
    text_addr = text_documents.parse_text_stream_addr(args)
    text_stream = text_documents.TextStream(*text_addr)
    count_addr = word_counts.parse_count_stream_addr(args)
    count_stream = word_counts.CountStream(*count_addr)

    ab = wallaroo.ApplicationBuilder("Word Count Application")
    ab.new_pipeline("Split and Count", text_stream.source())
    ab.to_parallel(split)
    ab.to_state_partition(count_word, WordTotal, "word totals", partition)
    ab.to_sink(count_stream.sink())
    return ab.build()


@wallaroo.computation_multi(name="split into words")
def split(data):
    punctuation = " !\"#$%&\'()*+,-./:;<=>?@[\\]^_`{}|~"
    words = []
    for line in data.split("\n"):
        clean_line = line.lower().strip(punctuation)
        for word in clean_line.split(" "):
            clean_word = word.strip(punctuation)
            words.append(clean_word)
    return words


@wallaroo.state_computation(name="Count Word")
def count_word(word, word_totals):
    word_totals.update(word)
    return (word_totals.get_count(), True)


class WordTotal(object):
    def __init__(self):
        self.word = ""
        self.total = 0

    def update(self, word):
        self.word = word
        self.total += 1

    def get_count(self):
        return WordCount(self.word, self.total)


class WordCount(object):
    def __init__(self, word, count):
        self.word = word
        self.count = count


@wallaroo.partition
def partition(data):
    return data
