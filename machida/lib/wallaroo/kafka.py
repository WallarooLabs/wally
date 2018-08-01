# Copyright 2018 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.

import argparse
from functools import wraps

from builder import _validate_arity_compatability

class CustomSourceCLIParser(object):
    def __init__(self, args, decoder):
        opts = parse_source_options(args)
        self.topic = opts[0]
        self.brokers = opts[1]
        self.log_level = opts[2]
        self.decoder = decoder

    def to_tuple(self):
        return ("kafka", self.topic, self.brokers, self.log_level, self.decoder)


class CustomSinkCLIParser(object):
    def __init__(self, args, encoder):
        opts = parse_sink_options(args)
        self.topic = opts[0]
        self.brokers = opts[1]
        self.log_level = opts[2]
        self.max_produce_buffer_ms = opts[3]
        self.max_message_size = opts[4]
        self.encoder = encoder

    def to_tuple(self):
        return ("kafka", self.topic, self.brokers, self.log_level,
                self.max_produce_buffer_ms, self.max_message_size, self.encoder)


class DefaultSourceCLIParser(object):
    def __init__(self, decoder, name="kafka_source"):
        self.decoder = decoder
        self.name = name

    def to_tuple(self):
        return ("kafka-internal", self.name, self.decoder)


class DefaultSinkCLIParser(object):
    def __init__(self, encoder, name="kafka_sink"):
        self.encoder = encoder
        self.name = name

    def to_tuple(self):
        return ("kafka-internal", self.name, self.encoder)


def parse_source_options(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('--kafka_source_topic', dest="topic",
                        default="")
    parser.add_argument('--kafka_source_brokers', dest="brokers",
                        default="")
    parser.add_argument('--kafka_source_log_level', dest="log_level",
                        default="Warn",
                        choices=["Fine", "Info", "Warn", "Error"])
    known_args = parser.parse_known_args(args)[0]
    brokers = [_parse_broker(b) for b in known_args.brokers.split(",")]
    return (known_args.topic, brokers, known_args.log_level)


def parse_sink_options(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('--kafka_sink_topic', dest="topic",
                        default="")
    parser.add_argument('--kafka_sink_brokers', dest="brokers",
                        default="")
    parser.add_argument('--kafka_sink_log_level', dest="log_level",
                        default="Warn",
                        choices=["Fine", "Info", "Warn", "Error"])
    parser.add_argument('--kafka_sink_max_produce_buffer_ms',
                        dest="max_produce_buffer_ms",
                        type=int,
                        default=0)
    parser.add_argument('--kafka_sink_max_message_size',
                        dest="max_message_size",
                        type=int,
                        default=100000)
    known_args = parser.parse_known_args(args)[0]
    brokers = [_parse_broker(b) for b in known_args.brokers.split(",")]
    return (known_args.topic, brokers, known_args.log_level,
            known_args.max_produce_buffer_ms, known_args.max_message_size)


def _parse_broker(broker):
    """
    `broker` is a string of `host[:port]`, return a tuple of `(host, port)`
    """
    host_and_port = broker.split(":")
    host = host_and_port[0]
    port = "9092"
    if len(host_and_port) == 2:
        port = host_and_port[1]
    return (host, port)


def decoder(decoder_function):
    _validate_arity_compatability(decoder_function, 1)
    @wraps(decoder_function)
    class C:
        def __call__(self, *args):
            return self
    return C()


def encoder(encoder_function):
    _validate_arity_compatability(encoder_function, 1)
    @wraps(encoder_function)
    class C:
        def encode(self, data):
            return encoder_function(data)
        def __call__(self, *args):
            return self
    return C()
