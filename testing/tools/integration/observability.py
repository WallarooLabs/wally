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
import logging
import time
from types import FunctionType
from functools import partial
import re
import traceback
import sys
import time

from errors import (DuplicateKeyError,
                    TimeoutError)
from external import run_shell_cmd
from logger import INFO2
from stoppable_thread import StoppableThread


# Make string instance checking py2 and py3 compatible below
try:
    basestring
except:
    basestring = str


class ObservabilityTimeoutError(TimeoutError):
    pass


class ObservabilityQueryError(Exception):
    pass


class ObservabilityResponseError(Exception):
    pass


QUERY_TYPES = {
    'partition-query': 'partition-query',
    'partition-counts': 'partition-count-query',
    'cluster-status': 'cluster-status-query',
    'state-entity-query': 'state-entity-query'}


def external_sender_query(addr, query_type):
    """
    Use external_sender to query the cluster for observability data.
    """
    t = QUERY_TYPES[query_type]
    cmd = ('external_sender --external {} --type {} --json'
           .format(addr, t))
    res = run_shell_cmd(cmd)
    try:
        assert(res.success)
    except AssertionError:
        raise AssertionError("Failed to query cluster for '{}' with the "
                             "following error:\n{}".format(t, res.output))
    return stdout


def partitions_query(addr):
    """
    Query the worker at the given address for its partition routing
    information.
    """
    stdout = external_sender_query(addr, 'partition-query')
    try:
        return json.loads(stdout)
    except Exception as err:
        e = ObservabilityResponseError("Failed to deserialize observability"
                                      " response:\n{!r}".format(stdout))
        logging.error(e)
        raise


def multi_states_query(addresses):
    """
    Query the workers at the given addresses for their partitions.
    Returns a dictionary of {address: {'stdout': raw_response,
                                       'data': parsed response}}
    """
    responses = {}
    # collect responses
    for name, addr in addresses:
        try:
            resp = external_sender_query(addr, 'state-entity-query')
        except Exception as err:
            logging.error(err)
            raise err
        try:
            # try to parse responses
            responses[name] = json.loads(resp)
        except Exception as err:
            e = ObservabilityResponseError(
                "Failed to deserialize observability response from {} ({}):\n{!r}"
                .format(name, addr, resp))
            logging.error(e)
            raise
    return responses


def cluster_status_query(addr):
    """
    Query the worker at the given address for its cluster status information.
    """
    stdout = external_sender_query(addr, 'cluster-status')
    try:
        return json.loads(stdout)
    except Exception as err:
        e = ObservabilityResponseError("Failed to deserialize observability"
                                      " response:\n{!r}".format(stdout))
        logging.error(e)
        raise


def partition_counts_query(addr):
    """
    Query the worker at the given address for its partition counts
    information.
    """
    stdout = external_sender_query(addr, 'partition-counts')
    try:
        return json.loads(stdout)
    except Exception as err:
        e = ObservabilityResponseError("Failed to deserialize observability"
                                      " response:\n{!r}".format(stdout))
        logging.error(e)
        raise


def state_entity_query(addr):
    """
    Query the worker at the given address for its state entities
    """
    stdout = external_sender_query(addr, 'state-entity-query')
    try:
        return json.loads(stdout)
    except Exception as err:
        e = ObservabilityResponseError("Failed to deserialize observability"
                                      " response:\n{!r}".format(stdout))
        logging.error(e)
        raise


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

    def __init__(self, query_func, query_args, tests, timeout=30, period=2):
        """
        - `query_func` is an argument-free function to query an observability
        status. You can use `functools.partial` to create it.
        - `query_args` is a list of arguments to pass the query function.
          Pass an empty list if no arguments are required.
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
            # make sure it's not a (test, args kwargs) tuple
            if len(tests) in (2,3):
                if isinstance(tests[1], (list, tuple, dict)):
                    self.tests = [tests]
            else:
                self.tests = tests
        else:
            self.tests = [tests]
        self.tests = [self._normalize_test_tuple(t) for t in self.tests]
        self.query_func = query_func
        if isinstance(query_args, (bytes, basestring)):
            self.query_args = [query_args]
        else:
            self.query_args = query_args
        self.query_func_name = get_func_name(query_func)
        self.period = period

    def _normalize_test_tuple(self, t):
        if isinstance(t, (tuple,list)):
            name = get_func_name(t[0])
            test = t[0]
            args = tuple()
            kwargs = tuple()
            if len(t) == 1:
                pass
            elif len(t) == 2:
                if isinstance(t[1], dict):
                    kwargs = tuple(t[1].items())
                else:
                    args = tuple(t[1])
            elif len(t) == 3:
                args = tuple(t[1])
                kwargs = tuple(t[2].items())
            else:
                raise ValueError("Test tuple must be "
                                 "(test[, args[, kwargs]])")
            return (name, test, args, kwargs)
        else:
            return (get_func_name(t), t, tuple(), frozenset())

    def run(self):
        started = time.time()
        while not self.stopped():
            try:
                query_result = self.query_func(*self.query_args)
            except Exception as err:
                # sleep and retry but only if timeout hasn't elapsed
                if (time.time() - started) <= self.timeout:
                    time.sleep(self.period)
                    continue
                else:  # Timeout has elapsed, return this error!
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
                    t_res = t[1](deepcopy(query_result), *t[2], **dict(t[3]))
                except Exception as err:
                    tb = traceback.format_exc()
                    errors[t] = (err, tb)

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
                        " - {}: {}({})\n{}".format(
                            t[0], type(err).__name__,
                            str(err),
                            '\n'.join((
                                "  -> {}".format(s) for s in tb.splitlines())))
                        for t, (err, tb),in errors.items()))))
                # Pack the query result into the error object
                self.error.query_result = query_result
                self.stop()
                break
            time.sleep(self.period)


class RunnerReadyChecker(StoppableThread):
    __base_name__ = 'RunnerReadyChecker'
    pattern = re.compile('Application has successfully initialized')

    def __init__(self, runners, timeout=30):
        super(RunnerReadyChecker, self).__init__()
        self.runners = runners
        self.name = self.__base_name__
        self._path = self.runners[0].file.name
        self.timeout = timeout
        self.error = None

    def run(self):
        with open(self._path, 'rb') as r:
            started = time.time()
            while not self.stopped():
                r.seek(0)
                stdout = r.read()
                if not stdout:
                    time.sleep(0.1)
                    continue
                else:
                    if self.pattern.search(stdout):
                        logging.debug('Application reports it is ready.')
                        self.stop()
                        break
                if time.time() - started > self.timeout:
                    outputs = runners_output_format(self.runners)
                    self.error = TimeoutError(
                        'Application did not report as ready after {} '
                        'seconds. It had the following outputs:\n===\n{}'
                        .format(self.timeout, outputs))
                    self.stop()
                    break


class RunnerChecker(StoppableThread):
    __base_name__ = 'RunnerChecker'

    def __init__(self, runner, patterns, timeout=30, start_from=0):
        super(RunnerChecker, self).__init__()
        self.name = self.__base_name__
        self.runner = runner
        self.runner_name = runner.name
        self.start_from = start_from
        self._path = runner.file.name
        self.timeout = timeout
        self.error = None
        if isinstance(patterns, (list, tuple)):
            self.patterns = patterns
        else:
            self.patterns = [pattern]
        self.compiled = [re.compile(p) for p in patterns]

    def run(self):
        with open(self._path, 'rb') as r:
            last_match = self.start_from
            started = time.time()
            while not self.stopped():
                r.seek(last_match)
                stdout = r.read()
                if not stdout:
                    time.sleep(0.1)
                    continue
                else:
                    match = self.compiled[0].search(stdout)
                    if match:
                        logging.debug('Pattern %r found in runner STDOUT.'
                                      % match.re.pattern)
                        self.compiled.pop(0)
                        last_match = self.start_from
                        if self.compiled:
                            continue
                        self.stop()
                        break
                if time.time() - started > self.timeout:
                    r.seek(self.start_from)
                    stdout = r.read()
                    self.error = TimeoutError(
                        'Runner {!r} did not have patterns {!r}'
                        ' after {} seconds.'
                        .format(self.runner_name,
                                [rx.pattern for rx in self.compiled],
                                self.timeout))
                    self.stop()
                    break


####################################
# Query response parsing functions #
####################################
def joined_partition_query_data(responses):
    """
    Join partition query responses from multiple workers into a single
    partition map.
    Raise error on duplicate partitions.
    """
    steps = {}
    for worker in responses.keys():
        for step in responses[worker].keys():
            if step not in steps:
                steps[step] = {}
            for part in responses[worker][step]:
                if part in steps[step]:
                    dup0 = worker
                    dup1 = steps[step][part]
                    raise DuplicateKeyError("Found duplicate keys! Step: {}, "
                                            "Key: {}, Loc1: {}, Loc2: {}"
                                            .format(step, part, dup0, dup1))
                steps[step][part] = worker
    return steps
