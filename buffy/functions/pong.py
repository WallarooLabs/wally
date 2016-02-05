#!/usr/bin/env python3

"""
Pong

A game of distributed Pong.
"""

FUNC_NAME = 'Pong'

class UnknownInputError(Exception):
    pass


def func(input):
    if input == 'ping':
        return 'pong'
    elif input == 'pong':
        return 'ping'
    else:
        raise UnknownInputError('Unknown input: {!r}'.format(input))

