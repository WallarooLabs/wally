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


import string
import struct
import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    word_partitions = list(string.ascii_lowercase)
    word_partitions.append("!")

    ab = wallaroo.ApplicationBuilder("Word Count Application")
    ab.new_pipeline("Split and Count",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to_parallel(split)
    ab.to_state_partition(count_word, WordTotals, "word totals",
        partition, word_partitions)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


@wallaroo.computation_multi(name="split into words")
def split(data):
    punctuation = " !\"#$%&'()*+,-./:;<=>?@[\]^_`{|}~"

    words = []

    for line in data.split("\n"):
        clean_line = line.lower().strip(punctuation)
        for word in clean_line.split(' '):
            clean_word = word.strip(punctuation)
            words.append(clean_word)

    return words


@wallaroo.state_computation(name="Count Word")
def count_word(word, word_totals):
    word_totals.update(word)
    return (word_totals.get_count(word), True)


class WordTotals(object):
    def __init__(self):
        self.word_totals = {}

    def update(self, word):
        if self.word_totals.has_key(word):
            self.word_totals[word] = self.word_totals[word] + 1
        else:
            self.word_totals[word] = 1

    def get_count(self, word):
        return WordCount(word, self.word_totals[word])


class WordCount(object):
    def __init__(self, word, count):
        self.word = word
        self.count = count


@wallaroo.partition
def partition(data):
    if data[0] >= 'a' or data[0] <= 'z':
        return data[0]
    else:
        return "!"


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    return bs.decode("utf-8")


@wallaroo.encoder
def encoder(data):
    return data.word + " => " + str(data.count) + "\n"
