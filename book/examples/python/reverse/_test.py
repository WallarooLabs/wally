import struct

from reverse import application_setup
from reverse import Decoder
from reverse import Encoder
from reverse import Reverse


def test_decoder():
    dec = Decoder()
    assert(dec.header_length() == 4)
    assert(dec.payload_length('\x00\x00\x00\x04') == 4)
    assert(dec.decode('hello') == 'hello')


def test_reverse():
    rev = Reverse()
    assert(rev.name() == 'reverse')
    assert(rev.compute('hello') == 'olleh')


def test_encode():
    enc = Encoder()
    assert(enc.encode('1234') == '1234\n')


class InputStream(object):
    def __init__(self, text):
        self.text = text
        self.pos = 0

    def read(self, num):
        if self.pos >= len(self.text):
            raise IndexError
        start = self.pos
        self.pos += num
        return self.text[start:self.pos]


def test_flow():
    app = application_setup([])
    msg = '1234'
    message = InputStream(struct.pack('>L{}s'.format(len(msg)), len(msg), msg))
    header_length = app[1][2].header_length()
    payload_length = app[1][2].payload_length(message.read(header_length))
    data = app[1][2].decode(message.read(payload_length))
    result = app[2][1]().compute(data)
    output = app[3][1].encode(result)
    assert(output == (msg[::-1] + '\n'))
