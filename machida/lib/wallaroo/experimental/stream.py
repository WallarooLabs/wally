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


# TODO: rethink some of this API around partitioning discussion
# class StreamDescription(object):
#     """
#     This offers a description of a given stream. Construct it using:

#        ... TODO EXAMPLE HERE ...

#     Customization can be done by subclassing this type and is the recommended
#     way to provide computed descriptions (instead of passing computed values
#     to the constructor). On the other hand, if you have fixed values, the base
#     constructor is recommend.
#     """

#     def __init__(self, **kwargs):
#         self._partitions = kwargs['partitions']
#         self._durability = kwargs['durability']
#         self._sequencing = kwargs['sequencing']
#         self._decoder = kwargs['decoder'] or identity_decoder
#         self._encoder = kwargs['encoder'] or identity_encoder

#     def partitions(self):
#         """
#         Explain partitions
#         """
#         return self._partitions

#     def durability(self):
#         """
#         Explain durability
#         """
#         return self._durability

#     def sequencing(self):
#         """
#         Explain sequencing
#         """
#         return self._sequencing

#     def encoder(self):
#         """
#         Explain encoder
#         """
#         return self._encoder

#     def decoder(self):
#         """
#         Expplain decoder
#         """
#         return self._decoder


# A decorator class used because we use decode rather than call in machida and
# also require header_length and payload_length even though those are fixed in
# this specific implementation now.
class stream_message_decoder(object):

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


# A decorator class used because we use encode rather than call in machida.
class stream_message_encoder(object):

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


class StreamDecoderError(Exception):
    pass


@stream_message_decoder
def identity_decoder(message):
    return message


@stream_message_encoder
def identity_encoder(message):
    if not isinstance(message, str):
        raise StreamDecoderError(
            "Unable to decode message type: {}".format(type(message)))
    # wallaroo does not currently frame outgoing messages for us
    return message
