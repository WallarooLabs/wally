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

import cPickle
import string
import struct

import wallaroo
import wallaroo.experimental
from partitioned_redis_stream import TextStream

def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    text_stream = TextStream(host = in_host, base_port = in_port)
    count_storage = wallaroo.experimental.ExternalSink(out_host, out_port, encoder)

    ab = wallaroo.ApplicationBuilder("Word Count Application")
    ab.new_pipeline("Split and Count", text_stream.source())
    ab.to_parallel(split)
    ab.to_state_partition(count_word, WordTotal, "word totals", partition)
    ab.to_sink(count_storage)
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


@wallaroo.experimental.stream_message_decoder
def decoder(bs):
    return bs.decode("utf-8")


@wallaroo.experimental.stream_message_encoder
def encoder(data):
    output = (data.word, data.count)
    return cPickle.dumps(output)
