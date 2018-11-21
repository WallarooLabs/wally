import string
import struct
import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    lines = wallaroo.source("Split and Count",
                        wallaroo.TCPSourceConfig(in_host, in_port, decode_lines))
    pipeline = lines\
        .to(split)\
        .key_by(extract_word)\
        .to(count_word)\
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_word_count))

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
def decode_line(bs):
    return bs.decode("utf-8")


@wallaroo.encoder
def encode_word_count(data):
    output = data.word + " => " + str(data.count) + "\n"
    return output.encode("utf-8")
