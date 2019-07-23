# Copyright 2019 The Wallaroo Authors.
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


from copy import deepcopy
from functools import partial
import logging
import time
import traceback
from types import FunctionType
import sys

from integration.errors import TimeoutError
from integration.stoppable_thread import StoppableThread


class CompletesWhenError(Exception):
    pass


class CompletesWhenTimeoutError(TimeoutError):
    pass


def get_func_name(f):
    """
    Recursively look for the original function's name.
    Works for both regular functions created with `def` as well as
    functions created with `functools.partial`.
    """
    if isinstance(f, FunctionType):
        return f.__name__
    elif isinstance(f, partial):
        return get_func_name(f.func)
    raise ValueError("Can't get func_name of provided function {}".format(f))


class CompletesWhenNotifier(StoppableThread):
    """
    Run a notifier loop with a query function and a check condition function
    """
    def __init__(self, context, test_func, timeout=90, period=1):
        super().__init__()
        self.context = context
        self.test_func = test_func
        self.test_func_name = get_func_name(test_func)
        self.error = None
        self.timeout = timeout
        self.period = period

    def stop(self, error=None):
        super().stop(error)

    def run(self):
        logging.debug("Scheduling CompletesWhenNotifier")
        started = time.time()
        while not self.stopped():
            res = None
            try:
                res = self.test_func(self.context)
            except Exception as err:
                self.error = err

            # If result are error free, break
            if res is True:
                self.stop()
                break

            # Else either wait for next cycle or timeout.
            if time.time() - started > self.timeout:
                test_error = self.error
                self.error = CompletesWhenTimeoutError(
                    "CompletesWhenNotifier(context={!r}, test_func={!r}, "
                    "timeout={!r}, period={!r}) timed out "
                    "with result:\n\t"
                    "{}\nAnd error:\n\t{}".format(
                        self.context,
                        self.test_func_name,
                        self.timeout,
                        self.period,
                        res,
                        self.error))
                self.error.test_error = test_error
                self.stop()
                break
            time.sleep(self.period)
