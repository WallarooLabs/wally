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
import inspect
import struct
from functools import wraps


class SourceConnectorConfig(object):
    def __init__(self, name, encoder, decoder, host='127.0.0.1', port=None):
        self._name = name
        self._encoder = encoder
        self._decoder = decoder
        self._host = host
        self._port = port

    def to_tuple(self):
        return ("source_connector", self._host, str(self._port), self._decoder)

    def _assign(self, host, port):
        self._host = host
        self._port = port

    def _is_unassigned(self):
        return self._port == None


class SinkConnectorConfig(object):
    def __init__(self, name, encoder, decoder, host='127.0.0.1', port=None):
        self._name = name
        self._encoder = encoder
        self._decoder = decoder
        self._host = host
        self._port = port

    def to_tuple(self):
        return ("sink_connector", self._host, str(self._port), self._encoder)

    def _assign(self, host, port):
        self._host = host
        self._port = port

    def _is_unassigned(self):
        return self._port == None


def parse_input_addrs(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('-i', '--in', dest="input_addrs")
    input_addrs = parser.parse_known_args(args)[0].input_addrs
    # split H1:P1,H2:P2... into [(H1, P1), (H2, P2), ...]
    return [tuple(x.split(':')) for x in input_addrs.split(',')]


def parse_output_addrs(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('-o', '--out', dest="output_addrs")
    output_addrs = parser.parse_known_args(args)[0].output_addrs
    # split H1:P1,H2:P2... into [(H1, P1), (H2, P2), ...]
    return [tuple(x.split(':')) for x in output_addrs.split(',')]


def decoder(header_length, length_fmt):
    def wrapped(decoder_function):
        _validate_arity_compatability(decoder_function, 1)
        @wraps(decoder_function)
        class C:
            def header_length(self):
                return header_length
            def payload_length(self, bs):
                return struct.unpack(length_fmt, bs)[0]
            def decode(self, bs):
                return decoder_function(bs)
            def __call__(self, *args):
                return self
        return C()
    return wrapped


def encoder(encoder_function):
    _validate_arity_compatability(encoder_function, 1)
    @wraps(encoder_function)
    class C:
        def encode(self, data):
            return encoder_function(data)
        def __call__(self, *args):
            return self
    return C()


def _validate_arity_compatability(obj, arity):
    """
    To assist in proper API use, it's convenient to fail fast with erros as
    soon as possible. We use this function to check things we decorate for
    compatibility with our desired number of arguments.
    """
    if not callable(obj):
        raise WallarooParameterError(
            "Expected a callable object but got a {0}".format(obj))
    spec = inspect.getargspec(obj)
    upper_bound = len(spec.args)
    lower_bound = upper_bound - (len(spec.defaults) if spec.defaults else 0)
    if arity > upper_bound or arity < lower_bound:
        raise WallarooParameterError((
            "Incompatible function arity, your function must allow {0} "
            "arguments."
            ).format(arity))