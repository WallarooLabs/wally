#!/usr/bin/env python3

"""
Convenience utilities for handling data streams encoded with forward-only
stream parsing in mind.

encode(text) returns a binary encoded message of the format
LHHTTT
where TTT is the binary text, HH is the length of the text in hexadecimal,
and L is the length of the hexadecimal length string, in a single hexadecimal
character.
This format allows for a maximum message size of 1152921504606846975 bytes.

The code consuming the stream is still responsible for ensuring it has
accumulated the entire communication from the sender before sending it to
decode().
This can be done by applying the following procedure for an incoming data
stream:
1. read the first character and apply hex_to_int to it to obtain L in decimal.
2. read the next L characters, apply hex_to_int to them to obtain message
   length HH in decimal.
3. continue reading chunks from the stream until an additional HH bytes have
   been accumulated.
4. pass the resulting byte buffer to the decode() function.
5. listen to the next incoming stream.
"""


class InvalidLengthError(Exception):
    pass


def int_to_hex(num):
    """Convert an integer to its hexadecimal value"""
    return '{:x}'.format(num)


def hex_to_int(text):
    """Convert a hexadecimal string to its integer value"""
    return int(text, 16)


def encode(text):
    """Encode a text message into the LHHTTT binary format."""
    msg = text.encode(encoding='UTF-8')
    msg_length_hex = int_to_hex(len(msg)).encode(encoding='UTF-8')
    msg_length_length = int_to_hex(len(msg_length_hex)).encode(encoding='UTF-8')
    if len(msg_length_length) != 1:
        raise InvalidLengthError('Message length is greater than the maximum '
                                 '1152921504606846975 bytes permitted by '
                                 'this protocol')
    return b''.join((msg_length_length, msg_length_hex, msg))


def decode(blob):
    """Decode a binary buffer in the LHHTTT format and return its text."""
    # Note that for bytes objects b'...', b[0] is an integer, while b[0:1]
    # is a bytes object of length 1 (e.g. the first byte). Therefore, to slice
    # our blob in whole-byte lengths, we must use slice notation rather than
    # index access notation, even when accessing only a single byte.
    # See https://docs.python.org/3/library/stdtypes.html#bytes for reference.

    length_length = hex_to_int(blob[:1].decode(encoding='UTF-8'))
    msg_length = hex_to_int(blob[1:1+length_length].decode(encoding='UTF-8'))
    buffer_length = 1+length_length+msg_length
    if len(blob) == buffer_length:
        return blob[1+length_length:].decode('UTF-8')
    else:
        raise InvalidLengthError('Buffer length mismatch. Expected {} bytes,'
                                 ' got {} bytes.'.format(buffer_length,
                                                         len(blob)))


###########################################################################
##                    Unit Tests                                         ##
def test_int_to_hex():
    assert(int_to_hex(10) == 'a')


def test_hex_to_int():
    assert(hex_to_int('a') == 10)


def test_encode():
    # ascii input
    assert(encode('hello world') == b'1bhello world')
    # unicode input
    assert(encode('𝐇𝐞𝐥𝐥𝐨 𝐰𝐨𝐫𝐥𝐝') == b'229\xf0\x9d\x90\x87\xf0\x9d\x90\x9e\xf0\x9d\x90\xa5\xf0\x9d\x90\xa5\xf0\x9d\x90\xa8 \xf0\x9d\x90\xb0\xf0\x9d\x90\xa8\xf0\x9d\x90\xab\xf0\x9d\x90\xa5\xf0\x9d\x90\x9d')  ## noqa


def test_decode():
    # ascii input
    assert(decode(b'1bhello world') == 'hello world')
    # unicode input
    assert(decode(b'229\xf0\x9d\x90\x87\xf0\x9d\x90\x9e\xf0\x9d\x90\xa5\xf0\x9d\x90\xa5\xf0\x9d\x90\xa8 \xf0\x9d\x90\xb0\xf0\x9d\x90\xa8\xf0\x9d\x90\xab\xf0\x9d\x90\xa5\xf0\x9d\x90\x9d') == '𝐇𝐞𝐥𝐥𝐨 𝐰𝐨𝐫𝐥𝐝')  ## noqa

