import wallaroo.experimental


class TextStream(object):

    def __init__(self, host, base_port):
        self.host = host
        self.base_port = int(base_port)

    def source(self):
        return wallaroo.experimental.ExternalSource(
            host = self.host,
            port = self.base_port,
            decoder = text_decoder)


@wallaroo.experimental.stream_message_decoder
def text_decoder(message):
    return message.decode("utf-8")


@wallaroo.experimental.stream_message_encoder
def text_encoder(message):
    return message.encode("utf-8")
