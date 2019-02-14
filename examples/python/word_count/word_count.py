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
This is an example application that receives strings of text, splits it into
individual words and counts the occurrences of each word.
"""

import string
import struct
import wallaroo


def application_setup(args):
    in_name, in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    lines = wallaroo.source("Split and Count",
                        wallaroo.TCPSourceConfig(in_name, in_host, in_port,
                                                 decode_lines))
    pipeline = (lines
        .to(split)
        .key_by(extract_word)
        .to(count_word)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_word_count)))

    return wallaroo.build_application("Word Count Application", pipeline)


@wallaroo.computation_multi(name="split into words")
def split(lines):
    punctuation = " !\"#$%&\'()*+,-./:;<=>?@[\\]^_`{|}~"

    words = []

    for line in lines.split("\n"):
        clean_line = line.lower().strip(punctuation)
        for word in clean_line.split(" "):
            clean_word = word.strip(punctuation)
            words.append(clean_word)

    return words


class WordTotal(object):
    count = 0


@wallaroo.state_computation(name="count word", state=WordTotal)
def count_word(word, word_total):
    word_total.count = word_total.count + 1
    return WordCount(word, word_total.count)


class WordCount(object):
    def __init__(self, word, count):
        self.word = word
        self.count = count


@wallaroo.key_extractor
def extract_word(word):
    return word


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decode_lines(bs):
    return bs.decode("utf-8")


@wallaroo.encoder
def encode_word_count(word_count):
    output = word_count.word + " => " + str(word_count.count) + "\n"
    return output.encode("utf-8")
