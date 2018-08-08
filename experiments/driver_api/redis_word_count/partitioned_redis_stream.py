import wallaroo.experimental

class TextStream(wallaroo.experimental.StreamDescription):

    def __init__(self, host, base_port):
        super(partitions = 2)
        self.host = host
        self.base_port = base_port

    def source(self):
        return [
            self._build_source(self.base_port),
            self._build_source(self.base_port + 1)
        ]

    def _build_source(self, port):
        wallaroo.experimental.ExternalSource(self.host, port, self.decoder),
