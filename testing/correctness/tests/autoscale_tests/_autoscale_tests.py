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

from __future__ import print_function

# import requisite components for integration test
from integration import (add_runner,
                         clean_resilience_path,
                         cluster_status_query,
                         CrashedWorkerError,
                         ex_validate,
                         get_port_values,
                         iter_generator,
                         Metrics,
                         MetricsData,
                         ObservabilityNotifier,
                         partition_counts_query,
                         partitions_query,
                         PipelineTestError,
                         Reader,
                         Runner,
                         RunnerChecker,
                         RunnerReadyChecker,
                         runners_output_format,
                         Sender,
                         setup_resilience_path,
                         Sink,
                         SinkAwaitValue,
                         start_runners,
                         TimeoutError)

from collections import Counter
from functools import partial
from itertools import cycle
import json
import logging
import os
import re
from string import lowercase
from struct import calcsize, pack, unpack
import tempfile
import time


class AutoscaleTestError(Exception):
    def __init__(self, args, as_error=None, as_steps=[]):
        super(AutoscaleTestError, self).__init__(args)
        self.as_error = as_error
        self.as_steps = as_steps


class AutoscaleTimeoutError(AutoscaleTestError):
    pass


fmt = '>I2sQ'
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


def send_shrink_cmd(host, port, names=[], count=1):
    # Trigger log rotation with external message
    cmd_external_trigger = ('cluster_shrinker --external {}:{} --workers {}'
                            .format(host, port,
                                    ','.join(names) if names else count))

    success, stdout, retcode, cmd = ex_validate(cmd_external_trigger)
    try:
        assert(success)
    except AssertionError:
        raise AssertionError('External shrink trigger failed with '
                             'the error:\n{}'.format(stdout))
    return stdout


def phase_validate_output(runners, sink, expected):
    # Validate captured output
    try:
        validate(sink.data, expected)
    except AssertionError:
        outputs = runners_output_format(runners)
        raise AssertionError('Validation failed on expected output. '
                             'Worker outputs are included below:'
                             '\n===\n{}'.format(outputs))


def phase_validate_partitions(runners, partitions, joined=[], left=[]):
    """
    Use the partition map to determine whether new workers have joined and
    departing workers have left.
    """
    joined_set = set(joined)
    left_set = set(left)
    # Compute set of workers with partitions
    workers = set()
    for p_type in partitions.values():
        for step in p_type.values():
            for key in step.keys():
                if len(step[key]) > 0:
                    workers.add(key)

    try:
        assert(workers.issuperset(joined_set))
    except AssertionError as err:
        missing = sorted(list(joined_set.difference(workers)))
        outputs = runners_output_format(runners)
        raise AssertionError('{} do not appear to have joined! '
                             'Worker outputs are included below:'
                             '\n===\n{}'.format(missing, outputs))

    try:
        assert(workers.isdisjoint(left_set))
    except AssertionError as err:
        reamining = sorted(list(workers.intersection(left_set)))
        outputs = runners_output_format(runners)
        raise AssertionError('{} do not appear to have left! '
                             'Worker outputs are included below:'
                             '\n===\n{}'.format(w, outputs))


def sign(i):
    if i > 0:
        return 'p'
    elif i < 0:
        return 'n'
    else:
        return 'z'


def compact_sign(ops):
    new = [ops[0]]
    for o in ops[1:]:
        if sign(new[-1]) == sign(o):
            new[-1] += o
        elif sign(o) == 'z':
            continue
        else:
            new.append(o)
    return new


def lowest_point(ops):
    l = None
    p = 0
    for o in ops:
        p += o
        if l is None:
            l  = p
        if p < l:
            l = p
    return l


def inverted(d):
    """
    Invert a partitions query response dict from
        {stateless_partitions: {step: {worker: [partition ids]}},
         state_partitions: {step: {worker: [partition ids]}}}
    to
        {stateless_partitions: {step: {partition_id: worker}},
         state_partitions: {step: {partition_id: worker}}}
    """
    o = {}
    for ptype in d:
        o[ptype] = {}
        for step in d[ptype]:
            o[ptype][step] = {}
            for worker in d[ptype][step]:
                for pid in d[ptype][step][worker]:
                    o[ptype][step][pid] = worker
    return o


# Observability Validation Test Functions
def get_crashed_runners(runners):
    """
    Get a list of crashed runners, if any exist.
    """
    return filter(lambda r: r.poll(), runners)


def test_crashed_workers(runners):
    """
    Test if there are any crashed workers and raise an error if yes
    """
    crashed = get_crashed_runners(runners)
    if crashed:
        raise CrashedWorkerError("Some workers have crashed.")


def test_worker_count(count, status):
    """
    Test that there `count` workers are reported as active in the
    cluster status query response
    """
    assert(len(status['worker_names']) == count)
    assert(status['worker_count'] == count)


def test_all_workers_have_partitions(partitions):
    """
    Test that all workers have partitions
    """
    assert(map(len, partitions['state_partitions']['letter-state']
                    .values()).count(0) == 0)


def test_cluster_is_processing(status):
    """
    Test that the cluster's 'processing_messages' status is True
    """
    assert(status['processing_messages'] is True)


def test_cluster_is_not_processing(status):
    """
    Test that the cluster's 'processing messages' status is False
    """
    assert(status['processing_messages'] is False)


def test_migrated_partitions(pre_partitions, workers, partitions):
    """
    Test that post-migration partition data matches up to expected data based
    on pre-migration partition data.
    """
    # invert the partitions dicts
    i_pre = inverted(pre_partitions)
    i_post = inverted(partitions)
    keys = ['state_partitions']
    for joining in workers.get('joining', {}):
        for ptype in keys:
            for step in partitions[ptype]:
                for pid in partitions[ptype][step][joining]:
                    assert(i_pre[ptype][step][pid] != joining)
    for leaving in workers.get('leaving', {}):
        for ptype in keys:
            for step in pre_partitions[ptype]:
                for pid in pre_partitions[ptype][step][leaving]:
                    assert(i_post[ptype][step][pid] != leaving)


# Autoscale tests runner functions

def autoscale_sequence(command, ops=[1], cycles=1, initial=None):
    """
    Run an autoscale test for a given command by performing grow and shrink
    operations, as denoted by positive and negative integers in the `ops`
    parameter, a `cycles` number of times.
    `initial` may be used to define the starting number of workers. If it is
    left undefined, the minimum number required so that the number of workers
    never goes below zero will be determined and used.
    """
    try:
        _autoscale_sequence(command, ops, cycles, initial)
    except Exception as err:
        if hasattr(err, 'as_steps'):
            print("Autoscale Sequence test failed after the operations {}."
                  .format(err.as_steps))
        if hasattr(err, 'as_error'):
            print("Autoscale Sequence test had the following the error "
                  "message:\n{}".format(err.as_error))
        if hasattr(err, 'runners'):
            if filter(lambda r: r.poll() != 0, err.runners):
                outputs = runners_output_format(err.runners,
                        from_tail=5, filter_fn=lambda r: r.poll() != 0)
                print("Some autoscale Sequence runners exited badly. "
                      "They had the following "
                      "output tails:\n===\n{}".format(outputs))
        if hasattr(err, 'query_result') and 'PRINT_QUERY' in os.environ:
            logging.error("The test error had the following query result"
                          " attached:\n{}"
                          .format(json.dumps(err.query_result)))
        raise

def _autoscale_sequence(command, ops=[], cycles=1, initial=None):
    host = '127.0.0.1'
    sources = 1

    if isinstance(ops, int):
        ops = [ops]

    # If no initial workers value is given, determine the minimum number
    # required at the start so that the cluster never goes below 1 worker.
    # If a number is given, then verify it is sufficient.
    if ops:
        lowest = lowest_point(ops*cycles)
        if lowest < 1:
            min_workers = abs(lowest) + 1
        else:
            min_workers = 1
        if isinstance(initial, int):
            assert(initial >= min_workers)
            workers = initial
        else:
            workers = min_workers
    else:  # Test is only for setup using initial workers
        assert(initial > 0)
        workers = initial

    batch_size = 10
    interval = 0.05
    sender_timeout = 30 # Counted from when Sender is stopped
    runner_join_timeout = 30

    res_dir = tempfile.mkdtemp(dir='/tmp/', prefix='res-data.')
    setup_resilience_path(res_dir)

    steps = []

    runners = []
    try:
        try:
            # Create sink, metrics, reader, sender
            sink = Sink(host)
            metrics = Metrics(host)
            lowercase2 = [a+b for a in lowercase for b in lowercase]
            char_cycle = cycle(lowercase2)
            expected = Counter()
            def count_sent(s):
                expected[s] += 1

            reader = Reader(iter_generator(
                items=char_cycle, to_string=lambda s: pack('>2sI', s, 1),
                on_next=count_sent))

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

            # Prepare query functions with host and port pre-defined
            query_func_partitions = partial(partitions_query, host,
                                            external_port)
            query_func_partition_counts = partial(partition_counts_query,
                                                  host, external_port)
            query_func_cluster_status = partial(cluster_status_query, host,
                                                external_port)

            # Start the initial runners
            start_runners(runners, command, host, inputs, outputs,
                          metrics_port, control_port, external_port, data_port,
                          res_dir, workers, worker_ports)

            # Verify cluster is processing messages
            obs = ObservabilityNotifier(query_func_cluster_status,
                test_cluster_is_processing)
            obs.start()
            obs.join()
            if obs.error:
                raise obs.error

            # Verify that `workers` workers are active
            # Create a partial function
            partial_test_worker_count = partial(test_worker_count, workers)
            obs = ObservabilityNotifier(query_func_cluster_status,
                partial_test_worker_count)
            obs.start()
            obs.join()
            if obs.error:
                raise obs.error

            # Verify all workers start with partitions
            obs = ObservabilityNotifier(query_func_partitions,
                test_all_workers_have_partitions)
            obs.start()
            obs.join()
            if obs.error:
                raise obs.error

            # start sender
            sender = Sender(host, input_ports[0], reader, batch_size=batch_size,
                            interval=interval)
            sender.start()
            # Give the cluster 1 second to build up some state
            time.sleep(1)

            # Perform autoscale cycles
            for cyc in range(cycles):
                for joiners in ops:
                    # Verify cluster is processing before proceeding
                    obs = ObservabilityNotifier(query_func_cluster_status,
                        test_cluster_is_processing, timeout=30)
                    obs.start()
                    obs.join()
                    if obs.error:
                        raise obs.error

                    # Test for crashed workers
                    test_crashed_workers(runners)

                    # get partition data before autoscale operation begins
                    pre_partitions = query_func_partitions()
                    steps.append(joiners)
                    joined = []
                    left = []
                    if joiners > 0:  # autoscale: grow
                        # create a new worker and have it join
                        new_ports = get_port_values(num=(joiners * 2), host=host,
                                                    base_port=25000)
                        joiner_ports = zip(new_ports[::2], new_ports[1::2])
                        for i in range(joiners):
                            add_runner(runners, command, host, inputs, outputs,
                                       metrics_port,
                                       control_port, external_port, data_port, res_dir,
                                       joiners, *joiner_ports[i])
                            joined.append(runners[-1])

                        # Verify cluster has resumed processing
                        obs = ObservabilityNotifier(query_func_cluster_status,
                            test_cluster_is_processing, timeout=120)
                        obs.start()
                        obs.join()
                        if obs.error:
                            raise obs.error

                        # Test: all workers have partitions, partitions ids
                        # for new workers have been migrated from pre-join
                        # workers
                        # create list of joining workers
                        diff_names = {'joining': [r.name for r in joined]}
                        # Create partial function of the test with the
                        # data baked in
                        tmp = partial(test_migrated_partitions, pre_partitions, diff_names)
                        # Start the test notifier
                        obs = ObservabilityNotifier(query_func_partitions,
                            [test_all_workers_have_partitions,
                             tmp])
                        obs.start()
                        obs.join()
                        if obs.error:
                            raise obs.error

                    elif joiners < 0:  # autoscale: shrink
                        # choose the most recent, still-alive runners to leave
                        leavers = abs(joiners)
                        idx = 1
                        while len(left) < leavers and idx < len(runners):
                            if runners[-idx].is_alive():
                                left.append(runners[-idx])
                            idx += 1
                        if len(left) < leavers:
                            raise AutoscaleTestError("Not enough workers left to "
                                                     "shrink! {} requested but "
                                                     "only {} live non-initializer"
                                                     "workers found!"
                                                    .format(joiners, len(left)))

                        # Send the shrink command
                        resp = send_shrink_cmd(host, external_port, names=[r.name for r in left])
                        print("Sent a shrink command for {}".format([r.name for r in left]))
                        print("Response was: {}".format(resp))

                        # Verify cluster has resumed processing
                        obs = ObservabilityNotifier(query_func_cluster_status,
                            test_cluster_is_processing, timeout=120)
                        obs.start()
                        obs.join()
                        if obs.error:
                            raise obs.error

                        # Test: all workers have partitions, partitions ids
                        # from departing workers have been migrated to remaining
                        # workers
                        # create list of leaving workers
                        diff_names = {'leaving': [r.name for r in left]}
                        # Create partial function of the test with the
                        # data baked in
                        tmp = partial(test_migrated_partitions, pre_partitions, diff_names)
                        # Start the test notifier
                        obs = ObservabilityNotifier(query_func_partitions,
                            [test_all_workers_have_partitions,
                             tmp])
                        obs.start()
                        obs.join()
                        if obs.error:
                            raise obs.error

                    else:  # Handle the 0 case as a noop
                        continue

                    # Test for crashed workers
                    test_crashed_workers(runners)

                    # Validate autoscale via partition query
                    try:
                        partitions = partitions_query(host, external_port)
                        phase_validate_partitions(runners, partitions,
                                                  joined=[r.name for r in joined],
                                                  left=[r.name for r in left])
                    except Exception as err:
                        print('error validating {} have joined and {} have left'
                              .format([r.name for r in joined],
                                      [r.name for r in left]))
                        raise

                    # Wait a second before the next operation, allowing some
                    # more data to go through the system
                    time.sleep(1)

            # Test for crashed workers
            test_crashed_workers(runners)

            # Test is done, so stop sender
            sender.stop()

            # wait until sender sends out its final batch and exits
            sender.join(sender_timeout)
            if sender.error:
                raise sender.error
            if sender.is_alive():
                sender.stop()
                raise TimeoutError('Sender did not complete in the expected '
                                   'period')

            print('Sender sent {} messages'.format(sum(expected.values())))

            # Use Sink value to determine when to stop runners and sink
            pack677 = '>I2sQ'
            pack27 = '>IsQ'
            await_values = [pack(pack677, calcsize(pack677)-4, c, v) for c, v in
                            expected.items()]
            #await_values = [pack(pack27, calcsize(pack27)-4, c, v) for c, v in
            #                expected.items()]
            stopper = SinkAwaitValue(sink, await_values, 30)
            stopper.start()
            stopper.join()
            if stopper.error:
                print('sink.data', len(sink.data))
                print('await_values', len(await_values))
                raise stopper.error

            # stop application workers
            for r in runners:
                r.stop()

            # Test for crashed workers
            test_crashed_workers(runners)

            # Stop sink
            sink.stop()

            # Stop metrics
            metrics.stop()

            # validate output
            phase_validate_output(runners, sink, expected)

        finally:
            for r in runners:
                r.stop()
            # Wait on runners to finish waiting on their subprocesses to exit
            for r in runners:
                r.join(runner_join_timeout)
            alive = []
            for r in runners:
                if r.is_alive():
                    alive.append(r)
            for r in runners:
                ec = r.poll()
                if ec != 0:
                    print('Worker {!r} exited with return code {}'
                          .format(r.name, ec))
                    print('Its last 5 log lines were:')
                    print('\n'.join(r.get_output().splitlines()[-5:]))
                    print()
            if alive:
                alive_names = ', '.join((r.name for r in alive))
                outputs = runners_output_format(runners)
                for a in alive:
                    a.kill()
            clean_resilience_path(res_dir)
            if alive:
                raise PipelineTestError("Runners [{}] failed to exit cleanly after"
                                        " {} seconds.\n"
                                        "Runner outputs are attached below:"
                                        "\n===\n{}"
                                        .format(alive_names, runner_join_timeout,
                                                outputs))
    except Exception as err:
        if not hasattr(err, 'as_steps'):
            err.as_steps = steps
        if not hasattr(err, 'runners'):
            err.runners = runners
        raise
