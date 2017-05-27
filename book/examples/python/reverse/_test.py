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


def test_integration():
    from wallaroo.integration import (HeaderGeneratorReader,
                                      ListGenerator,
                                      Metrics,
                                      Runner,
                                      Sender,
                                      Sink,
                                      time,
                                      Validator)
    input_set = ['one', 'two', 'three', 'four', 'five', 'six', 'seven',
                 'eight', 'nine', 'ten']
    expected_output = [w[::-1] for w in input_set]

    host = '127.0.0.1'
    sink_port = 7002
    metrics_port = 5001
    sender_port = 7010
    sink = Sink(host, sink_port)
    metrics = Metrics(host, metrics_port)
    #reader = HeaderGeneratorReader(SequenceGenerator(1000))
    reader = HeaderGeneratorReader(ListGenerator(input_set))
    sender = Sender(host, sender_port, reader, batch_size=4)
    sink.start()
    metrics.start()
    # TODO: Runner to run machida application
    # TODO: for now, run the machida application manually. You've got 3 seconds! GO!
    time.sleep(3)
    sender.start()
    sender.join()
    # TODO: Runner to terminate machida application
    time.sleep(1)
    sink.stop()
    metrics.stop()
    # TODO: decode output and validate against expected
    decoded = []
    for item in sink.data:
        for line in item.splitlines():
            if line:
                decoded.append(line)
    assert(expected_output == decoded)
