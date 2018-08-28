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

import struct

from wallaroo.builder import _validate_arity_compatability

# A decorator class used because we use decode rather than call in machida and
# also require header_length and payload_length even though those are fixed in
# this specific implementation now.
class StreamingMessageDecoder(object):

    def __init__(self, decoder):
        _validate_arity_compatability(decoder, 1)
        self._message_decoder = decoder

    def header_length(self):
        return 4

    def payload_length(self, bytes):
        return struct.unpack("<I", bytes)[0]

    def decode(self, data):
        meta_len = struct.unpack_from('<H', data)
        # We dropping the metadata on the floor for now, slice out the
        # remaining data for message decoding.
        message_data = data[struct.calcsize('<H') + meta_len :]
        return self._message_decoder(message_data)

    def __call__(self, *args):
        return self._message_decoder(*args)


def streaming_message_decoder(func):
    return StreamingMessageDecoder(func)


# A decorator class used because we use encode rather than call in machida.
class StreamingMessageEncoder(object):

    def __init__(self, encoder):
        _validate_arity_compatability(encoder, 1)
        self._message_encoder = encoder

    def encode(self, data, partition=None, sequence=None):
        encoded = self._message_encoder(data)
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

    def __call__(self, *args):
        # NOTE: I'm not sure when we use these __call__ forms. We may have
        # them in place so applications may call their functions. We should
        # be careful to avoid using this ourselves since it lacks the metadata
        # section of the payload and proper framing.
        # Longer term, the framing and metadata serializatoin will all be in
        # Pony so this decorator can be removed entirely.
        return self._message_encoder(*args)


def streaming_message_encoder(func):
    return StreamingMessageEncoder(func)


class StreamDecoderError(Exception):
    pass


@streaming_message_decoder
def identity_decoder(message):
    return message


@streaming_message_encoder
def identity_encoder(message):
    if not isinstance(message, str):
        raise StreamDecoderError(
            "Unable to decode message type: {}".format(type(message)))
    # wallaroo does not currently frame outgoing messages for us
    return message
