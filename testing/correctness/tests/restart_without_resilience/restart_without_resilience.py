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


# import requisite components for integration test
from integration import (ex_validate,
                         get_port_values,
                         Metrics,
                         Reader,
                         Runner,
                         RunnerReadyChecker,
                         Sender,
                         sequence_generator,
                         setup_resilience_path,
                         clean_resilience_path,
                         Sink,
                         SinkAwaitValue,
                         start_runners,
                         TimeoutError)
import os
import re
import struct
import tempfile
import time


def test_restart_pony():
    command = 'sequence_window'
    _test_restart(command)


def test_restart_machida():
    command = 'machida --application-module sequence_window'
    _test_restart(command)


def _test_restart(command):

    host = '127.0.0.1'
    sources = 1
    workers = 2
    res_dir = tempfile.mkdtemp(dir='/tmp/', prefix='res-data.')
    expect = 200
    last_value_0 = '[{}]'.format(','.join((str(expect-v) for v in range(6,-2,-2))))
    last_value_1 = '[{}]'.format(','.join((str(expect-1-v) for v in range(6,-2,-2))))
    await_values = (struct.pack('>I', len(last_value_0)) + last_value_0,
                   struct.pack('>I', len(last_value_1)) + last_value_1)


    setup_resilience_path(res_dir)

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)
        reader = Reader(sequence_generator(expect))

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        num_ports = sources + 3 * workers
        ports = get_port_values(num=num_ports, host=host)
        (input_ports, worker_ports) = (
            ports[:sources],
            [ports[sources:][i:i+3] for i in xrange(0,
                len(ports[sources:]), 3)])
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, res_dir, workers, worker_ports)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners, timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender
        sender = Sender(host, input_ports[0], reader, batch_size=1,
                        interval=0.05, reconnect=True)
        sender.start()
        time.sleep(0.2)

        # stop worker in a non-graceful fashion so that recovery files
        # aren't removed
        runners[-1].kill()

        ## restart worker
        runners.append(runners[-1].respawn())
        runners[-1].start()

        # wait until sender completes (~1 second)
        sender.join(30)
        if sender.error:
            raise sender.error
        if sender.is_alive():
            sender.stop()
            raise TimeoutError('Sender did not complete in the expected '
                               'period')

        # Wait for the last sent value expected at the worker
        stopper = SinkAwaitValue(sink, await_values, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            for r in runners:
                print r.name
                print r.get_output()
                print '---'
            print 'sink data'
            print sink.data
            print '---'
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()

        # Validate worker actually underwent recovery
        pattern_restarting = "Restarting a listener ..."
        stdout = runners[-1].get_output()
        try:
            assert(re.search(pattern_restarting, stdout) is not None)
        except AssertionError:
            raise AssertionError('Worker does not appear to have reconnected '
                                 'as expected. Worker output is '
                                 'included below.\nSTDOUT\n---\n%s'
                                 % stdout)
    finally:
        for r in runners:
            r.stop()
        clean_resilience_path(res_dir)
