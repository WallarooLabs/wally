#!/usr/bin/env python3

__FUNCS__ = {}


def get_function(func_name):
    return __FUNCS__[func_name.lower()]

# Import each function manually
# TODO: automate this part so function files are drop-in compatible
from .pong import FUNC_NAME, func  # noqa
__FUNCS__[FUNC_NAME.lower()] = (func, FUNC_NAME)

from .passthrough import FUNC_NAME, func  # noqa
__FUNCS__[FUNC_NAME.lower()] = (func, FUNC_NAME)

from .double import FUNC_NAME, func  # noqa
__FUNCS__[FUNC_NAME.lower()] = (func, FUNC_NAME)
