import struct
from enum import IntEnum

import wallaroo


def application_setup(args):
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    ab = wallaroo.ApplicationBuilder("Apache Log file analysis")
    ab.new_pipeline("convert",
                    wallaroo.TCPSourceConfig(in_host, in_port, Decoder()))
    ab.to(Count)
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, Encoder()))
    return ab.build()


class LogLine(object):

    def __init__(self, text):
        self.text = text


class Decoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        if bs == 'START_CHUNK':
            return wallaroo.ChunkMarker_Start()
        elif bs == 'END_CHUNK':
            return wallaroo.ChunkMarker_End()
        else:
            return LogLine(bs)


class Count(object):

### BEGIN API MOCK ###

    def __init__(self):
        self.reset()

    def reset(self):
        self.current_batch = []

    def compute(self, data):
        #this should be in a wrapper in the API with calls to on_start_chunk()
        #and on_end_chunk()
        if type(data) is wallaroo.ChunkMarker_Start:
            self.reset()
            return None
        elif type(data) is wallaroo.ChunkMarker_End:
            return self.process_batch(self.current_batch)
        elif type(data) is LogLine:
            self.current_batch.append(data)

### END API MOCK ###

    def name(self):
        return "Count log lines"

    def process_batch(self, batch_data):
        #print "batch length: {}".format(len(batch_data))
        return len(batch_data)


class Encoder(object):
    def encode(self, data):
        # data is an int
        return struct.pack('>II', 4, data)
