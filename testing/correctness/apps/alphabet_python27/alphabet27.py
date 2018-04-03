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


from string import lowercase
import struct
import pickle

import wallaroo


def application_setup(args, show_help):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    letter_partitions = [a for a in lowercase]
    letter_partitions.append('!')
    ab = wallaroo.ApplicationBuilder("alphabet")
    ab.new_pipeline("alphabet",
                    wallaroo.TCPSourceConfig(in_host, in_port, decoder))
    ab.to_state_partition(add_votes, TotalVotes, "letter-state",
                          partition, letter_partitions)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


@wallaroo.partition
def partition(data):
    return data.letter[0]


class TotalVotes(object):
    def __init__(self):
        self.letter = "X"
        self.votes = 0

    def update(self, votes):
        self.letter = votes.letter
        self.votes += votes.votes

    def get_votes(self):
        return Votes(self.letter, self.votes)


class Votes(object):
    def __init__(self, letter, votes):
        self.letter = letter
        self.votes = votes


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    (letter, vote_count) = struct.unpack(">sI", bs)
    return Votes(letter, vote_count)


@wallaroo.state_computation(name="add votes")
def add_votes(data, state):
    state.update(data)
    return (state.get_votes(), True)


@wallaroo.encoder
def encoder(data):
    # data is a Votes
    letter = data.letter
    votes = data.votes
    return struct.pack(">LsQ", 9, data.letter, data.votes)
