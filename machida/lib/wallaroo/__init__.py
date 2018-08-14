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

from functools import wraps
import pickle

from builder import (ApplicationBuilder, _validate_arity_compatability)


# Top-level machida compatibility support:

from .tcp import (
    SourceConfig as TCPSourceConfig,
    SinkConfig as TCPSinkConfig,
    decoder,
    encoder,
    parse_input_addrs as tcp_parse_input_addrs,
    parse_output_addrs as tcp_parse_output_addrs,
)

from .kafka import (
    DefaultSourceCLIParser as DefaultKafkaSourceCLIParser,
    DefaultSinkCLIParser as DefaultKafkaSinkCLIParser,
    CustomSourceCLIParser as CustomKafkaSourceCLIParser,
    CustomSinkCLIParser as CustomKafkaSinkCLIParser,
    parse_source_options as parse_kafka_source_options,
    parse_sink_options as parse_kafka_sink_options,
    decoder as kafka_decoder,
    encoder as kafka_encoder,
)

from .byoi import (
    SourceConfig as BYOISourceConfig,
    SinkConfig as BYOISinkConfig,
    decoder,
    encoder,
    parse_input_addrs as byoi_parse_input_addrs,
    parse_output_addrs as byoi_parse_output_addrs,
)

def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


def computation(name):
    def wrapped(computation_function):
        _validate_arity_compatability(computation_function, 1)
        @wraps(computation_function)
        class C:
            def name(self):
                return name
            def compute(self, data):
                return computation_function(data)
            def __call__(self, *args):
                return self
        return C()
    return wrapped


def state_computation(name):
    def wrapped(computation_function):
        _validate_arity_compatability(computation_function, 2)
        @wraps(computation_function)
        class C:
            def name(self):
                return name
            def compute(self, data, state):
                return computation_function(data, state)
            def __call__(self, *args):
                return self
        return C()
    return wrapped


def computation_multi(name):
    def wrapped(computation_function):
        _validate_arity_compatability(computation_function, 1)
        @wraps(computation_function)
        class C:
            def name(self):
                return name
            def compute_multi(self, data):
                return computation_function(data)
            def __call__(self, *args):
                return self
        return C()
    return wrapped


def state_computation_multi(name):
    def wrapped(computation_function):
        _validate_arity_compatability(computation_function, 2)
        @wraps(computation_function)
        class C:
            def name(self):
                return name
            def compute_multi(self, data, state):
                return computation_function(data, state)
            def __call__(self, *args):
                return self
        return C()
    return wrapped


def partition(fn):
    _validate_arity_compatability(fn, 1)
    @wraps(fn)
    class C:
        def partition(self, data):
            return fn(data)
        def __call__(self, *args):
            return self
    return C()
