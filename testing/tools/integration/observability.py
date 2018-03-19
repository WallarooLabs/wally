# Copyright 2017 The Wallaroo Authors.
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
import json
import time
from types import FunctionType
from functools import partial

from integration import (ex_validate,
               StoppableThread,
               TimeoutError)


class ObservabilityTimeoutError(TimeoutError):
    pass


class ObservabilityQueryError(Exception):
    pass


QUERY_TYPES = {
    'partition-query': 'partition-query',
    'partition-counts': 'partition-count-query',
    'cluster-status': 'cluster-status-query'}


def external_sender_query(host, port, query_type):
    """
    Use external_sender to query the cluster for observability data.
    """
    t = QUERY_TYPES[query_type]
    cmd = ('external_sender --external {}:{} --type {} --json'
           .format(host, port, t))
    success, stdout, retcode, cmd = ex_validate(cmd)
    try:
        assert(success)
    except AssertionError:
        raise AssertionError("Failed to query cluster for '{}' with the "
                             "following error:\n:{}".format(t, stdout))
    return stdout


def partitions_query(host, port):
    """
    Query the worker at the given address for its partition routing
    information.
    """
    stdout = external_sender_query(host, port, 'partition-query')
    return json.loads(stdout)


def cluster_status_query(host, port):
    """
    Query the worker at the given address for its cluster status information.
    """
    stdout = external_sender_query(host, port, 'cluster-status')
    return json.loads(stdout)


def partition_counts_query(host, port):
    """
    Query the worker at the given address for its partition counts
    information.
    """
    stdout = external_sender_query(host, port, 'partition-counts')
    return json.loads(stdout)


def get_func_name(f):
    """
    Recursively look for the original function's name.
    Works for both regular functions created with `def` as well as
    functions created with `functools.partial`.
    """
    if isinstance(f, FunctionType):
        return f.func_name
    elif isinstance(f, partial):
        return get_func_name(f.func)
    raise ValueError("Can't get func_name of provided function {}".format(f))


class ObservabilityNotifier(StoppableThread):
    """
    A notifier based status test.
    A list of tests is applied to an observability query result set. If all
    tests pass, the notifier thread exits with a successful status. If any of
    the tests fail, the notifier thread sleeps for 1 second and retries. If
    the timeout period elapses before all tests pass, the thread exits with an
    error status.
    """
    __base_name__ = 'ObservabilityNotifier'

    def __init__(self, query_func, tests, timeout=240, period=2):
        """
        - `query_func` is an argument-free function to query an observability
        statys. You can use `functools.partial` to create it.
        - `tests` is either a single function or a list of functions, each of
        which will be executed on a copy of the result set. A test should fail
        by raising an error, and pass by returning True.
        - `timeout` is the period in seconds the notifier should wait before
        exiting with an error status if any of the tests is still failing.
        The default is 30 seconds.
        - `period` is the time in seconds to wait between queries. The default
        is 2 seconds.
        """
        super(ObservabilityNotifier, self).__init__()
        self.name = self.__base_name__
        self.timeout = timeout
        self.error = None
        if isinstance(tests, (list, tuple)):
            self.tests = tests
        else:
            self.tests = [tests]
        self.tests = [(t, get_func_name(t)) for t in self.tests]
        self.query_func = query_func
        self.query_func_name = get_func_name(query_func)
        self.period = period

    def run(self):
        started = time.time()
        while not self.stopped():
            try:
                query_result = self.query_func()
            except Exception as err:
                self.error = ObservabilityQueryError(
                    "Query function '{}' has experienced an error:\n{}({})"
                    .format(self.query_func_name, type(err).__name__,
                            str(err)))
                self.stop()
                break
            # Run tests, collect results
            errors = {}
            for t in self.tests:
                try:
                    t_res = t[0](deepcopy(query_result))
                except Exception as err:
                    errors[t] = err

            # If all result are error free, break
            if not errors:
                self.stop()
                break

            # Else if any result is not True, either wait for next cycle
            # or timeout.
            if time.time() - started > self.timeout:
                self.error = ObservabilityTimeoutError(
                    "Observability test timed out after {} seconds with the"
                    " following tests"
                    " still failing:\n{}".format(self.timeout, "\n".join((
                        "    {}: {}({})".format(
                            t[1], type(err).__name__,
                            str(err))
                        for t, err,in errors.items()))))
                self.stop()
                break
            time.sleep(self.period)
