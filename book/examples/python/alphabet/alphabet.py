import struct
import pickle

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("alphabet")
    ab.new_pipeline("alphabet", Decoder(),
                    wallaroo.TCPSourceConfig(in_host, in_port))
    ab.to_stateful(AddVotes(), LetterStateBuilder(), "letter state")
    ab.to_sink(Encoder(),
               wallaroo.TCPSinkConfig(out_host, out_port))
    return ab.build()


def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


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
        # Return a new Votes instance here!
        return Votes(letter, vbl.votes)


class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        (letter, vote_count) = struct.unpack(">sI", bs)
        return Votes(letter, vote_count)


class AddVotes(object):
    def name(self):
        return "add votes"

    def compute(self, data, state):
        state.update(data)
        return (state.get_votes(data.letter), True)


class Encoder(object):
    def encode(self, data):
        # data is a Votes
        return struct.pack(">IsQ", 9, data.letter, data.votes)
