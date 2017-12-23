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
from integration import (add_runner,
                         ex_validate,
                         get_port_values,
                         iter_generator,
                         Metrics,
                         MetricsParser,
                         Reader,
                         Runner,
                         RunnerChecker,
                         RunnerReadyChecker,
                         Sender,
                         setup_resilience_path,
                         Sink,
                         SinkAwaitValue,
                         start_runners,
                         TimeoutError)

from collections import Counter
from itertools import cycle
from string import lowercase
from struct import pack, unpack
import re
import time


fmt = '>LsQ'
def decode(bs):
    return unpack(fmt, bs)[1:3]


def pre_process(decoded):
    totals = {}
    for c, v in decoded:
        totals[c] = v
    return totals


def process(data):
    decoded = []
    for d in data:
        decoded.append(decode(d))
    return pre_process(decoded)


def validate(raw_data, expected):
    data = process(raw_data)
    assert(data == expected)


def test_autoscale_grow_pony_by_1():
    command = 'alphabet'
    _test_autoscale_grow(command, worker_count=2)


def test_autoscale_grow_machida_by_1():
    command = 'machida --application-module alphabet'
    _test_autoscale_grow(command, worker_count=2)


def test_autoscale_grow_pony_by_4():
    command = 'alphabet'
    _test_autoscale_grow(command, worker_count=5)


def test_autoscale_grow_machida_by_4():
    command = 'machida --application-module alphabet'
    _test_autoscale_grow(command, worker_count=5)


def _test_autoscale_grow(command, worker_count=1):
    host = '127.0.0.1'
    sources = 1
    workers = 1
    joiners = worker_count - workers
    res_dir = '/tmp/res-data'
    expect = 2000

    patterns_i = ([re.escape(r'***Worker worker{} attempting to join the '
                             r'cluster. Sent necessary information.***'
                             .format(i)) for i in range(1, joiners + 1)]
                  +
                  [re.escape(r'Migrating partitions to worker1'),
                   re.escape(r'--All new workers have acked migration '
                             r'batch complete'),
                   re.escape(r'~~~Resuming message processing.~~~')])
    patterns_w = [re.escape(r'***Successfully joined cluster!***'),
                  re.escape(r'~~~Resuming message processing.~~~')]

    setup_resilience_path(res_dir)

    runners = []
    try:
        # Create sink, metrics, reader, sender
        sink = Sink(host)
        metrics = Metrics(host)

        char_gen = cycle(lowercase)
        char_1000 = [next(char_gen) for i in range(1000)]
        char_2000 = [next(char_gen) for i in range(1000)]
        expected = Counter(char_1000 + char_2000)

        reader1 = Reader(iter_generator(char_1000,
                                        lambda s: pack('>sI', s, 1)))
        reader2 = Reader(iter_generator(char_2000,
                                        lambda s: pack('>sI', s, 1)))

        await_values = [pack('>IsQ', 9, c, v) for c, v in
                        expected.items()]

        # Start sink and metrics, and get their connection info
        sink.start()
        sink_host, sink_port = sink.get_connection_info()
        outputs = '{}:{}'.format(sink_host, sink_port)

        metrics.start()
        metrics_host, metrics_port = metrics.get_connection_info()
        time.sleep(0.05)

        num_ports = sources + 3 + (2 * (workers - 1))
        ports = get_port_values(num=num_ports, host=host)
        (input_ports, (control_port, data_port, external_port),
         worker_ports) = (ports[:sources],
                          ports[sources:sources+3],
                          zip(ports[-(2*(workers-1)):][::2],
                              ports[-(2*(workers-1)):][1::2]))
        inputs = ','.join(['{}:{}'.format(host, p) for p in
                           input_ports])

        start_runners(runners, command, host, inputs, outputs,
                      metrics_port, control_port, external_port, data_port,
                      res_dir, workers, worker_ports)

        # Wait for first runner (initializer) to report application ready
        runner_ready_checker = RunnerReadyChecker(runners, timeout=30)
        runner_ready_checker.start()
        runner_ready_checker.join()
        if runner_ready_checker.error:
            raise runner_ready_checker.error

        # start sender1
        sender1 = Sender(host, input_ports[0], reader1, batch_size=10,
                        interval=0.05)
        sender1.start()

        # wait until sender1 completes (~5 seconds)
        sender1.join(30)
        if sender1.error:
            raise sender1.error
        if sender1.is_alive():
            sender1.stop()
            raise TimeoutError('Sender1 did not complete in the expected '
                               'period')

        # create a new worker and have it join
        new_ports = get_port_values(num=(joiners * 2), host=host,
                                    base_port=25000)
        joiner_ports = zip(new_ports[::2], new_ports[1::2])
        for i in range(joiners):
            add_runner(runners, command, host, inputs, outputs, metrics_port,
                       control_port, external_port, data_port, res_dir,
                       joiners, *joiner_ports[i])

        # Wait for runner to complete a log rotation
        join_checkers = []
        join_checkers.append(RunnerChecker(runners[0], patterns_i, timeout=30))
        for runner in runners[1:]:
            join_checkers.append(RunnerChecker(runner, patterns_w, timeout=30))
        for jc in join_checkers:
            jc.start()
        for jc in join_checkers:
            jc.join()
            if jc.error:
                print('RunnerChecker error for Join check on {}'
                      .format(jc.runner_name))

                outputs = [(r.name, r.get_output()) for r in runners]
                outputs = '\n===\n'.join(('\n---\n'.join(t) for t in outputs))
                raise TimeoutError(
                    'Worker {} join timed out in {} '
                    'seconds. The cluster had the following outputs:\n===\n{}'
                    .format(jc.runner_name, jc.timeout, outputs))


        # Start sender2
        sender2 = Sender(host, input_ports[0], reader2, batch_size=10,
                         interval=0.05)
        sender2.start()

        # wait until sender2 completes (~5 seconds)
        sender2.join(30)
        if sender2.error:
            raise sender2.error
        if sender2.is_alive():
            sender2.stop()
            raise TimeoutError('Sender2 did not complete in the expected '
                               'period')

        # Use Sink value to determine when to stop runners and sink
        stopper = SinkAwaitValue(sink, await_values, 30)
        stopper.start()
        stopper.join()
        if stopper.error:
            raise stopper.error

        # stop application workers
        for r in runners:
            r.stop()

        # Stop sink
        sink.stop()

        # Stop metrics
        metrics.stop()

        # parse metrics data and validate worker has shifted from 1 to 2
        # workers
        mp = MetricsParser()
        mp.load_string_list(metrics.data)
        mp.parse()
        # Now confirm that there are computations in each worker's metrics
        app_key = mp.data.keys()[0]  # 'metrics:Alphabet Poplarity Contest'
        worker_metrics = {w: [v for v in mp.data[app_key].get(w, [])
                                   if v[0] =='metrics']
                          for w in ['worker{}'.format(i) for i in
                                    range(1, joiners + 1)]}
        # Verify there is at least one entry for a computation with a nonzero
        # total value
        for w, m in worker_metrics.items():
            filtered = filter(lambda v: ((v[1]['metric_category'] ==
                                          'computation')
                                         and
                                         v[1]['total'] > 0),
                              m)
            print('filtered', filtered)
            try:
                assert(len(filtered) > 0)
            except AssertionError:
                outputs = [(r.name, r.get_output()) for r in runners]
                outputs = '\n===\n'.join(('\n---\n'.join(t) for t in outputs))
                raise AssertionError('{} did not process any data! '
                                     'Worker outputs are included below:'
                                     '\n===\n{}'.format(w, outputs))


        # Validate captured output
        try:
            validate(sink.data, expected)
        except AssertionError:
            outputs = [(r.name, r.get_output()) for r in runners]
            outputs = '\n===\n'.join(('\n---\n'.join(t) for t in outputs))
            raise AssertionError('Validation failed on expected output. '
                                 'Worker outputs are included below:'
                                 '\n===\n{}'.format(outputs))

    finally:
        for r in runners:
            r.stop()
