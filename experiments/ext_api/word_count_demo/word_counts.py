import argparse
import cPickle
import wallaroo.experimental


class CountStream(object):

    def __init__(self, host, port):
        self.host = host
        self.port = int(port)

    def sink(self):
        return wallaroo.experimental.SinkExtensionConfig(
            host=self.host,
            port=self.port,
            encoder=count_encoder)

    def extension(self):
        extension = wallaroo.experimental.SinkExtension(count_decoder)
        extension.listen(self.host, self.port, backlog=16)
        return extension


def parse_count_stream_addr(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--count-stream', dest="output_addr")
    output_addr = parser.parse_known_args(args)[0].output_addr
    return tuple(output_addr.split(':'))


@wallaroo.experimental.streaming_message_decoder
def count_decoder(message):
    return cPickle.loads(message)


@wallaroo.experimental.streaming_message_encoder
def count_encoder(message):
    print message.__dict__
    return cPickle.dumps((message.word.encode("utf-8"), message.count), -1)
