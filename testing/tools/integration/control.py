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
import time

from errors import (ExpectationError,
                    TimeoutError)
from stoppable_thread import StoppableThread
from observability import (cluster_status_query,
                           get_func_name,
                           ObservabilityNotifier)

from validations import is_processing


def wait_for_cluster_to_resume_processing(runners, timeout=30):
    # Wait until all workers have resumed processing
    waiting = set()
    for r in runners:
        if not r.is_alive():
            continue
        obs = ObservabilityNotifier(cluster_status_query,
            r.external,
            tests=is_processing, timeout=timeout)
        waiting.add(obs)
        obs.start()
    # Cycle through waiting until its empty or error
    t0 = time.time()
    while True:
        for obs in list(waiting):
            # short join
            obs.join(0.05)
            if obs.error:
                raise obs.error
            if obs.is_alive():
                continue
            else:
                waiting.remove(obs)
        # check completion
        if waiting:
            # check timeout!
            if time.time() - t0 > timeout:
                raise TimeoutError("Timed out after {} seconds while waiting "
                    "for cluster to resume processing.".format(timeout))
        else:
            return  # done!


class SinkExpect(StoppableThread):
    """
    Stop the sink after receiving an expected number of messages.
    """
    __base_name__ = 'SinkExpect'

    def __init__(self, sink, expected, timeout=30):
        super(SinkExpect, self).__init__()
        self.sink = sink
        self.expected = expected
        self.timeout = timeout
        self.name = self.__base_name__
        self.error = None

    def run(self):
        started = time.time()
        while not self.stopped():
            msgs = len(self.sink.data)
            if msgs > self.expected:
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

    def stop(self):
        super(SinkExpect, self).stop()


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
                            logging.debug("{} matched on value {!r}."
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

    def stop(self):
        super(SinkAwaitValue, self).stop()


def try_until_timeout(test, pre_process=None, timeout=30):
    """
    Try a test until it passes or the time runs out

    :parameters
    `test` - a runnable test function that raises an error if it fails
    `pre_process` - a runnable function that generates test input.
        The test input is used as the parameters for the function given by
        `test`.
    `timeout` - the timeout, in seconds, before the test is failed.
    """
    t0 = time.time()
    c = 0
    while True:
        c += 1
        logging.debug("try_until iteration {}".format(c))
        try:
            if pre_process:
                args = pre_process()
                test(*args)
            else:
                test()
        except Exception as err:
            logging.debug("iteration failed...")
            if time.time() - t0 > timeout:
                logging.warn("Failed on attempt {} of test: {}..."
                      .format(c, get_func_name(test)))
                raise
            time.sleep(2)
        else:
            return
