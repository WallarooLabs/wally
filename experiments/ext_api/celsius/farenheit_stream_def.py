import argparse
import cPickle
import wallaroo.experimental


class FarenheitStream(object):

    def __init__(self, host, port):
        self.host = host
        self.port = int(port)

    def sink(self):
        return wallaroo.experimental.SinkExtensionConfig(
            host=self.host,
            port=self.port,
            encoder=farenheit_encoder)

    def extension(self):
        extension = wallaroo.experimental.SinkExtension(farenheit_decoder)
        extension.listen(self.host, self.port, backlog=16)
        return extension


def parse_farenheit_stream_addr(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--farenheit-stream', dest="output_addr")
    output_addr = parser.parse_known_args(args)[0].output_addr
    return tuple(output_addr.split(':'))


@wallaroo.experimental.streaming_message_decoder
def farenheit_decoder(message):
    return cPickle.loads(message)


@wallaroo.experimental.streaming_message_encoder
def farenheit_encoder(message):
    return cPickle.dumps(("%.6f" % (message)).encode("utf-8"), -1)
