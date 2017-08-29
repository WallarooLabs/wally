import struct

import wallaroo


def application_setup(args):
    (in_topic, in_brokers,
     in_log_level) = wallaroo.kafka_parse_source_options(args)

    (out_topic, out_brokers, out_log_level, out_max_produce_buffer_ms,
     out_max_message_size) = wallaroo.kafka_parse_sink_options(args)

    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit with Kafka")

    ab.new_pipeline("convert",
                    wallaroo.KafkaSourceConfig(in_topic, in_brokers, in_log_level,
                                               Decoder()))

    ab.to(Multiply)
    ab.to(Add)

    ab.to_sink(wallaroo.KafkaSinkConfig(out_topic, out_brokers, out_log_level,
                                        out_max_produce_buffer_ms,
                                        out_max_message_size,
                                        Encoder()))
    return ab.build()


class Decoder(object):
    def decode(self, bs):
        return struct.unpack('>f', bs)[0]


class Multiply(object):
    def name(self):
        return "multiply by 1.8"

    def compute(self, data):
        return data * 1.8


class Add(object):
    def name(self):
        return "add 32"

    def compute(self, data):
        return data + 32


class Encoder(object):
    def encode(self, data):
        # data is a float
        return (struct.pack('>f', data), None)
