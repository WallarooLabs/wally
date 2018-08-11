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
This is an example application that takes "votes" for different letters of
the alphabet and keeps a running total of the votes received for each
letter. For each incoming message, it sends out a message with the total
votes for that letter. The total number of votes for each letter are stored
together in a single state object.
"""

import struct

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.byoi_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.byoi_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("alphabet")
    ab.new_pipeline("alphabet",
                    wallaroo.BYOISourceConfig(in_host, in_port, decoder))
    ab.to_stateful(add_votes, AllVotes, "letter state")
    ab.to_sink(wallaroo.BYOISinkConfig(out_host, out_port, encoder))
    return ab.build()


class Votes(object):
    def __init__(self, letter, votes):
        self.letter = letter
        self.votes = votes


class AllVotes(object):
    def __init__(self):
        self.votes_by_letter = {}

    def update(self, votes):
        letter = votes.letter
        vote_count = votes.votes
        votes_for_letter = self.votes_by_letter.get(letter, Votes(letter, 0))
        votes_for_letter.votes += vote_count
        self.votes_by_letter[letter] = votes_for_letter

    def get_votes(self, letter):
        vbl = self.votes_by_letter[letter]
        # Return a new Votes instance here!
        return Votes(letter, vbl.votes)


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    (letter, vote_count) = struct.unpack(">sI", bs)
    return Votes(letter, vote_count)


@wallaroo.state_computation(name="add votes")
def add_votes(data, state):
    state.update(data)
    return (state.get_votes(data.letter), True)


@wallaroo.encoder
def encoder(data):
    # data is a Votes
    return "%s => %d\n" % (data.letter, data.votes)
