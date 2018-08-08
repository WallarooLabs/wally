import cPickle
import wallaroo.experimental


class CountStream(object):

    def __init__(self, host, port):
        self.host = host
        self.port = int(port)

    def sink(self):
        return wallaroo.experimental.ExternalSink(
            host = self.host,
            port = self.port,
            encoder = count_encoder)


@wallaroo.experimental.stream_message_decoder
def count_decoder(message):
    return cPickle.loads(message)


@wallaroo.experimental.stream_message_encoder
def count_encoder(message):
    return cPickle.dumps((message.word.encode("utf-8"), message.count))
