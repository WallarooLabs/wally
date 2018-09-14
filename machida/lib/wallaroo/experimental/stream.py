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

import inspect
import struct
import sys

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
    if base_cls is _Encoder:
        class C(base_cls):
            def encode(self, data, partition=None, sequence=None):
                encoded = func(data)
                if partition:
                    part = str(partition)
                else:
                    part = ''
                if sequence:
                    seq = int(sequence)
                else:
                    seq = -1
                meta = struct.pack('<H', len(part) + struct.calcsize('<q')) + part + struct.pack('<q', seq)
                return struct.pack('<I', len(meta) + len(encoded)) + meta + encoded

    elif base_cls is _Decoder:
        class C(base_cls):
            def header_length(self):
                return struct.calcsize('<I')
            def payload_length(self, bs):
                return struct.unpack("<I", bs)[0]
            def decode(self, bs):
                meta_len = struct.unpack_from('<H', bs)[0]
                # We dropping the metadata on the floor for now, slice out the
                # remaining data for message decoding.
                message_data = bs[struct.calcsize('<H') + meta_len :]
                return func(message_data)
            def decoder(self):
                return func

    # Attach the new class to the module's global namespace and return it
    return _attach_to_module(C, base_cls.__name__, func)


class _BaseWrapped(object):
    def __call__(self, *args):
        return self


class _Encoder(_BaseWrapped):
    pass


class _Decoder(_BaseWrapped):
    pass


def stream_message_decoder(func):
    _validate_arity_compatability(func, 1)
    C = _wallaroo_wrap(func.__name__, func, _Decoder)
    return C()


def stream_message_encoder(func):
    _validate_arity_compatability(func, 1)
    C = _wallaroo_wrap(func.__name__, func, _Encoder)
    return C()


class StreamDecoderError(Exception):
    pass


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