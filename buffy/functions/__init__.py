#!/usr/bin/env python3.5

__FUNCS__ = {}


def get_function(func_name):
    return __FUNCS__[func_name]

# Import each function manually
# TODO: automate this part so function files are drop-in compatible
from .pong import FUNC_NAME, func
__FUNCS__[FUNC_NAME.lower()] = func

from .passthrough import FUNC_NAME, func
__FUNCS__[FUNC_NAME] = func

