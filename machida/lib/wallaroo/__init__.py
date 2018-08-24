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

import pickle
import struct
import sys

from builder import (ApplicationBuilder, _validate_arity_compatability)


# Top-level machida compatibility support:

from .tcp import (
    SourceConfig as TCPSourceConfig,
    SinkConfig as TCPSinkConfig,
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


def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


def _attach_to_module(cls, cls_name, func):
    # Do some scope mangling to create a uniquely named class based on
    # the decorated function's name and place it in the wallaroo module's
    # namespace so that pickle can find it.
    name = cls_name + '__' + func.__name__
    # Python2: use __name__
    if sys.version_info.major == 2:
        cls.__name__ = name
    # Python3: use __qualname__
    else:
        cls.__qualname__ = name

    globals()[name] = cls
    return globals()[name]


def _wallaroo_wrap(name, func, base_cls, **kwargs):
    # Case 1: Computations
    if issubclass(base_cls, _Computation):
        # Create the appropriate computation signature
        if base_cls._is_state:
            def comp(self, data, state):
                return func(data, state)
        else:
            def comp(self, data):
                return func(data)

        # Create a custom class type for the computation
        class C(base_cls):
            __doc__ = func.__doc__
            __module__ = __module__
            def name(self):
                return name

        # Attach the computation to the class
        # TODO: maybe move this to machida, using PyObject_IsInstance
        # instead of PyObject_HasAttrString
        if base_cls._is_multi:
            C.compute_multi = comp
        else:
            C.compute = comp

    # Case 2: _Partition
    elif base_cls is _Partition:
        class C(base_cls):
            def partition(self, data):
                return func(data)

    # Case 3: Encoder
    elif base_cls is _Encoder:
        class C(base_cls):
            def encode(self, data):
                return func(data)

    # Case 4: Decoder
    elif base_cls is _Decoder:
        header_length = kwargs['header_length']
        length_fmt = kwargs['length_fmt']
        class C(base_cls):
            def header_length(self):
                return header_length
            def payload_length(self, bs):
                return struct.unpack(length_fmt, bs)[0]
            def decode(self, bs):
                return func(bs)

    # Attach the new class to the module's global namespace and return it
    return _attach_to_module(C, base_cls.__name__, func)


class _BaseWrapped(object):
    def __call__(self, *args):
        return self


class _Computation(_BaseWrapped):
    _is_multi = False
    _is_state = False


def computation(name):
    def wrapped(func):
        _validate_arity_compatability(func, 1)
        C = _wallaroo_wrap(name, func, _StateComputation)
        return C()
    return wrapped


class _StateComputation(_Computation):
    _is_state = True


def state_computation(name):
    def wrapped(func):
        _validate_arity_compatability(func, 2)
        C = _wallaroo_wrap(name, func, _StateComputation)
        return C()
    return wrapped


class _ComputationMulti(_Computation):
    _is_multi = True


def computation_multi(name):
    def wrapped(func):
        _validate_arity_compatability(func, 1)
        C = _wallaroo_wrap(name, func, _ComputationMulti)
        return C()
    return wrapped


class _StateComputationMulti(_StateComputation):
    _is_multi = True


def state_computation_multi(name):
    def wrapped(func):
        _validate_arity_compatability(func, 2)
        C = _wallaroo_wrap(name, func, _StateComputationMulti)
        return C()
    return wrapped


class _Decoder(_BaseWrapped):
    pass


def decoder(header_length, length_fmt):
    def wrapped(func):
        _validate_arity_compatability(func, 1)
        C = _wallaroo_wrap(func.__name__, func, _Decoder,
                           header_length = header_length,
                           length_fmt = length_fmt)
        return C()
    return wrapped


class _Encoder(_BaseWrapped):
    pass


def encoder(func):
    _validate_arity_compatability(func, 1)
    C = _wallaroo_wrap(func.__name__, func, _Encoder)
    return C()


class _Partition(_BaseWrapped):
    pass


def partition(func):
    _validate_arity_compatability(func, 1)
    C = _wallaroo_wrap(func.__name__, func, _Partition)
    return C()
