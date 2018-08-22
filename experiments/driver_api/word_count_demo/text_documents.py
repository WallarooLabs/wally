import argparse
import wallaroo.experimental


class TextStream(object):

    # NOTE: We may be able to use defaults if we can add some kind of
    # protocol initialization here.
    def __init__(self, host, port):
        self.host = host
        self.port = int(port)

    def source(self):
        return wallaroo.experimental.ExternalSource(
            host=self.host,
            port=self.port,
            decoder=text_decoder)

    def driver(self):
        driver = wallaroo.experimental.SourceDriver(text_encoder)
        driver.connect(self.host, self.port)
        return driver


def parse_text_stream_addr(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--text-stream', dest="input_addr")
    input_addr = parser.parse_known_args(args)[0].input_addr
    return tuple(input_addr.split(':'))


@wallaroo.experimental.stream_message_decoder
def text_decoder(message):
    return message.decode("utf-8")


@wallaroo.experimental.stream_message_encoder
def text_encoder(message):
    return message.encode("utf-8")
