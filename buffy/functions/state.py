#!/usr/bin/env python3

"""
State adds statefulness to via a functional interface.
"""

from collections import Counter


class State:
    """
    State is a class used to store state in the buffy actors.

    Functional accessors are provided to interact with State.
    """
    pass


# Create module-local state object
state = State()


# Define accessor functionality
_NO_DEFAULT = object()  # This allows None to be used as a valid default value


def pop(name, default=_NO_DEFAULT):
    """Pop and return a named state object (list, counter, etc)"""
    try:
        return state.__dict__.pop(name)
    except KeyError:
        if default is not _NO_DEFAULT:
            return default
        raise AttributeError("No attribute named {}"
                             .format(name)) from KeyError


def pop_record(record, name, default=_NO_DEFAULT):
    """Pop and return a record from a named object"""
    try:
        return getattr(state, name).pop(record)
    except (AttributeError, IndexError, KeyError):
        if default is not _NO_DEFAULT:
            return default


def get_attribute(name, default=_NO_DEFAULT):
    """Get a top-level state object"""
    try:
        return getattr(state, name)
    except AttributeError:
        if default is not _NO_DEFAULT:
            setattr(state, name, default)
            return default


def get_record(record, name, default=_NO_DEFAULT):
    """Get a record from a named attribute"""
    try:
        return getattr(state, name)[record]
    except (AttributeError, IndexError, KeyError):
        if default is not _NO_DEFAULT:
            return default


def append(record, name):
    """Add record to a named list, creating a new list if it doesn't exist"""
    if not hasattr(state, name):
        setattr(state, name, list())
    getattr(state, name).append(record)


def add(record, value, name):
    """Add value to a record in a named counter"""
    if not hasattr(state, name):
        setattr(state, name, Counter())
    getattr(state, name)[record] += value


def multiply(record, value, name):
    """Multiply a record by value in a named counter"""
    if not hasattr(state, name):
        setattr(state, name, Counter())
    getattr(state, name)[record] *= value
