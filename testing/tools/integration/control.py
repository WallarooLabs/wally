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

import logging
from inspect import isfunction
import time

from .errors import (ClusterError,
                    ExpectationError,
                    TimeoutError)
from .stoppable_thread import StoppableThread
from .observability import (cluster_status_query,
                           get_func_name,
                           ObservabilityNotifier)

from .validations import is_processing


class WaitForClusterToResumeProcessing(StoppableThread):
    def __init__(self, runners, timeout=30, interval=0.05):
        super(WaitForClusterToResumeProcessing, self).__init__()
        self.name = 'WaitForClusterToResumeProcessing'
        # Wait until all workers have resumed processing
        self.runners = runners
        self.timeout = timeout
        self.interval = interval

    def run(self):
        waiting = set()
        for r in self.runners:
            if not r.is_alive():
                continue
            obs = ObservabilityNotifier(cluster_status_query,
                r.external,
                tests=is_processing, timeout=self.timeout)
            waiting.add(obs)
            obs.start()
        # Cycle through waiting until its empty or error
        t0 = time.time()
        while not self.stopped():
            for obs in list(waiting):
                # short join
                obs.join(self.interval)
                if obs.error:
                    self.stop(obs.error)
                    break
                if obs.is_alive():
                    continue
                else:
                    logging.log(1, "ObservabilityNotifier completed: {}"
                        .format(obs))
                    waiting.remove(obs)
            # check completion
            if waiting:
                # check timeout!
                if time.time() - t0 > self.timeout:
                    self.stop(TimeoutError("Timed out after {} seconds while waiting "
                        "for cluster to resume processing.".format(self.timeout)))
                    break
            else:
                break  # done!


class SinkExpect(StoppableThread):
    """
    Stop the sink after receiving an expected number of messages.
    """
    __base_name__ = 'SinkExpect'

    def __init__(self, sink, expected, timeout=30, allow_more=False):
        super(SinkExpect, self).__init__()
        self.sink = sink
        self.expected = expected
        self.timeout = timeout
        self.name = self.__base_name__
        self.error = None
        self.allow_more = allow_more

    def run(self):
        started = time.time()
        while not self.stopped():
            msgs = len(self.sink.data)
            if msgs > self.expected:
                if not self.allow_more:
                    self.error = ExpectationError('{}: has received too many '
                                                  'messages. Expected {} but got '
                                                  '{}.'.format(self.name,
                                                               self.expected,
                                                               msgs))
                self.stop()
                break
            if msgs == self.expected:
                self.stop()
                break
            if time.time() - started > self.timeout:
                self.error = TimeoutError('{}: has timed out after {} seconds'
                                          ', with {} messages. Expected {} '
                                          'messages.'.format(self.name,
                                                             self.timeout,
                                                             msgs,
                                                             self.expected))
                self.stop()
                break
            time.sleep(0.1)


class SinkAwaitValue(StoppableThread):
    """
    Stop the sink after receiving an expected value or values.
    """
    __base_name__ = 'SinkAwaitValue'

    def __init__(self, sink, values, timeout=30, func=lambda x: x):
        super(SinkAwaitValue, self).__init__()
        self.sink = sink
        if isinstance(values, (list, tuple)):
            self.values = set(values)
        else:
            self.values = set((values, ))
        self.timeout = timeout
        self.name = self.__base_name__
        self.error = None
        self.position = 0
        self.func = func

    def run(self):
        started = time.time()
        while not self.stopped():
            msgs = len(self.sink.data)
            if msgs and msgs > self.position:
                while self.position < msgs:
                    sink_data = self.func(self.sink.data[self.position])
                    for val in list(self.values):
                        if sink_data == val:
                            self.values.discard(val)
                            logging.log(1, "{} matched on value {!r}."
                                           .format(self.name,
                                                   val))
                    if not self.values:
                        self.stop()
                        break
                    self.position += 1
            if time.time() - started > self.timeout:
                self.error = TimeoutError('{}: has timed out after {} seconds'
                                          ', with {} messages. before '
                                          'receiving the awaited values '
                                          '{!r}.'.format(self.name,
                                                         self.timeout,
                                                         msgs,
                                                         self.values))
                self.stop()
                break
            time.sleep(0.1)


class TryUntilTimeout(StoppableThread):
    def __init__(self, test, pre_process=None, timeout=30, interval=0.1):
        """
        Try a test until it passes or the time runs out

        :parameters
        `test` - a runnable test function that raises an error if it fails
        `pre_process` - a runnable function that generates test input.
            The test input is used as the parameters for the function given by
            `test`.
        `timeout` - the timeout, in seconds, before the test is failed.
        """
        super(TryUntilTimeout, self).__init__()
        self.test = test
        self.pre_process = pre_process
        self.timeout = timeout
        self.interval = interval
        self.args = None

    def run(self):
        t0 = time.time()
        c = 0
        while not self.stopped():
            c += 1
            logging.log(1, "try_until iteration {}".format(c))
            try:
                if self.pre_process:
                    if isfunction(self.pre_process):
                        self.args = self.pre_process()
                    else:
                        self.args = self.pre_process
                    self.test(*self.args)
                else:
                    self.test()
            except Exception as err:
                logging.log(1, "iteration failed...")
                if time.time() - t0 > self.timeout:
                    logging.warn("Failed on attempt {} of test: {}..."
                          .format(c, get_func_name(self.test)))
                    logging.exception(err)
                    self.stop(err)
                else:
                    time.sleep(self.interval)
            else:
                return


class CrashChecker(StoppableThread):
    """
    Continuously check for crashed workers
    """
    __base_name__ = 'CrashChecker'

    def __init__(self, cluster, func=None):
        super(CrashChecker, self).__init__()
        self.cluster = cluster
        self.func = func

    def run(self):
        while not self.stopped():
            if self.func:
                crashed = self.cluster.get_crashed_workers(self.func)
            else:
                crashed = self.cluster.get_crashed_workers()
            if crashed:
                logging.debug("CrashChecker, results: {}".format(crashed))
                err = ClusterError("A crash was detected in the workers: {}"
                        .format(",".join(("{} ({}): {}")
                            .format(w.name, w.pid, w.returncode())
                                    for w in crashed)))
                self.cluster.raise_from_error(err)
                self.stop()
                break
            time.sleep(0.5)
