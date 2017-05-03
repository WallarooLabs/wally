import string
import struct

import wallaroo


def application_setup(args):
    letter_partitions = list(string.ascii_lowercase)
    ab = wallaroo.ApplicationBuilder("alphabet")
    ab.new_pipeline("alphabet", Decoder())
    ab.to_state_partition(AddVotes(), LetterStateBuilder(), "letter state",
                          LetterPartitionFunction(), letter_partitions)
    ab.to_sink(Encoder())
    return ab.build()


class LetterPartitionFunction(object):
    def partition(self, data):
        return data.letter[0]


class LetterStateBuilder(object):
    def build(self):
        return TotalVotes()


class TotalVotes(object):
    def __init__(self):
        self.letter = 'X'
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


class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        letter = chr(bs[0])
        vote_count = struct.unpack(">I", bs[1:])[0]
        return Votes(letter, vote_count)


class AddVotes(object):
    def name(self):
        return "add votes"

    def compute(self, data, state):
        state.update(data)
        return state.get_votes()


class Encoder(object):
    def encode(self, data):
        # data is a Votes
        letter = data.letter
        votes = data.votes
        return bytearray(letter, "utf-8") + struct.pack(">I", votes)
