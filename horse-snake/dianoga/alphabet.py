import struct

import wallaroo

def test_python():
    return "hello python"

def application_setup(args):
    ab = wallaroo.ApplicationBuilder("alphabet")

    ab.new_pipeline("alphabet", Decoder()).to_stateful(AddVotes(),
                                                       LetterStateBuilder(),
                                                       "letter state").to_sink(Encoder())

    return ab.build()

class LetterStateBuilder(object):
    def build(self):
        return AllVotes()

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
        return Votes(letter, vbl.votes)

class Decoder(object):
    def header_length(self):
        print "header_length"
        return 4

    def payload_length(self, bs):
        print "payload_length"

        l = struct.unpack(">I", bs)[0]
        return l

    def decode(self, bs):
        letter = chr(bs[0])
        vote_count = struct.unpack(">I", bs[1:])[0]
        return Votes(letter, vote_count)

class AddVotes(object):
    def name(self):
        return "add votes"

    def compute(self, data, state):
        print "Add Votes "
        state.update(data)
        return state.get_votes(data.letter)

class Encoder(object):
    def encode(self, data):
        # data is a Votes
        letter = data.letter
        votes = data.votes
        return bytearray(letter, "utf-8") + struct.pack(">I", votes)
