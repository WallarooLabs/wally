import argparse
import wallaroo.experimental


class CelsiusStream(object):

    # NOTE: We may be able to use defaults if we can add some kind of
    # protocol initialization here.
    def __init__(self, host, port):
        self.host = host
        self.port = int(port)

    def source(self):
        return wallaroo.experimental.SourceExtensionConfig(
            host=self.host,
            port=self.port,
            decoder=celsius_decoder)

    def extension(self):
        extension = wallaroo.experimental.SourceExtension(celsius_encoder)
        extension.connect(self.host, self.port)
        return extension


def parse_celsius_stream_addr(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--celsius-stream', dest="input_addr")
    input_addr = parser.parse_known_args(args)[0].input_addr
    return tuple(input_addr.split(':'))


@wallaroo.experimental.streaming_message_decoder
def celsius_decoder(message):
    return message.decode("utf-8")


@wallaroo.experimental.streaming_message_encoder
def celsius_encoder(message):
    return message.encode("utf-8")
