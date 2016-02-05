#!/usr/bin/env python3

"""
Pong

A game of distributed Pong.
"""

FUNC_NAME = 'Pong'

class UnknownInputError(Exception):
    pass


def func(input):
    if input == '14ping':
        return '14pong'
    elif input == '14pong':
        return '14ping'
    else:
        raise UnknownInputError('Unknown input: {!r}'.format(input))

