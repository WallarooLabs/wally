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
                         ex_validate,
                         get_port_values,
                         iter_generator,
                         Metrics,
                         MetricsData,
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
from itertools import cycle
import json
import re
from string import lowercase
from struct import pack, unpack
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


def query_partitions(host, port):
    """
    Query the worker at the given address for its partition routing
    information.
    """
    cmd = ('external_sender --external {}:{} --type partition-query'
           .format(host, port))
    success, stdout, retcode, cmd = ex_validate(cmd)
    try:
        assert(success)
    except AssertionError:
        raise AssertionError('Failed to query partition data with the '
                             'following error:\n:{}'.format(stdout))
    return json.loads(stdout.splitlines()[-1])


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
    Use the partition map to determine whether new workers of joined and
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
        raise err


def _autoscale_sequence(command, ops=[1], cycles=1, initial=None):
    host = '127.0.0.1'
    sources = 1

    if isinstance(ops, int):
        ops = [ops]

    # If no initial workers value is given, determine the minimum number
    # required at the start so that the cluster never goes below 1 worker.
    # If a number is given, then verify it is sufficient.
    bottom = min(min(compact_sign(ops*cycles)), sum(ops*cycles))
    if bottom < 1:
        min_workers = abs(bottom) + 1
    else:
        min_workers = 1
    if isinstance(initial, int):
        assert(initial >= min_workers)
        workers = initial
    else:
        workers = min_workers


    batch_size = 10
    interval = 0.05
    msgs_per_sec = int(batch_size/interval)
    base_time = 10  # Seconds
    cycle_time = 10  # seconds
    expect_time = base_time + cycle_time * cycles  # seconds
    expect = expect_time * msgs_per_sec
    sender_timeout = expect_time + 10  # seconds
    join_timeout = 200
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
            lowercase2 = [a + b for a in lowercase for b in lowercase]
            char_gen = cycle(lowercase2)
            chars = [next(char_gen) for i in range(expect)]
            expected = Counter(chars)

            reader = Reader(iter_generator(chars,
                                            lambda s: pack('>2sI', s, 1)))

            await_values = [pack('>I2sQ', 10, c, v) for c, v in
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

            # Get initial partition data
            partitions = query_partitions(host, external_port)
            # Verify all workers start with partitions
            assert(map(len, partitions['state_partitions']['letter-state']
                            .values()).count(0) == 0)

            # start sender
            sender = Sender(host, input_ports[0], reader, batch_size=batch_size,
                            interval=interval)
            sender.start()

            time.sleep(2)

            # Perform autoscale cycles
            start_froms = {r: 0 for r in runners}
            for cyc in range(cycles):
                for joiners in ops:
                    steps.append(joiners)
                    joined = []
                    left = []
                    if joiners > 0:
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
                            start_froms[runners[-1]] = 0

                        patterns_i = ([re.escape('***Worker {} attempting to join the '
                                                 'cluster. Sent necessary information.***'
                                                 .format(r.name)) for r in joined]
                                      +
                                      [re.escape('Migrating partitions to {}'.format(
                                          r.name)) for r in joined]
                                      +
                                      [re.escape('--All new workers have acked migration '
                                                 'batch complete'),
                                       re.escape('~~~Resuming message processing.~~~')])
                        patterns_j = [re.escape('***Successfully joined cluster!***'),
                                      re.escape('~~~Resuming message processing.~~~')]

                        # Wait for runners to complete joining
                        join_checkers = []
                        join_checkers.append(RunnerChecker(runners[0], patterns_i,
                            timeout=join_timeout,
                            start_from=start_froms[runners[0]]))
                        for runner in joined:
                            join_checkers.append(RunnerChecker(runner, patterns_j,
                                timeout=join_timeout,
                                start_from=start_froms[runner]))
                        for jc in join_checkers:
                            jc.start()
                        for jc in join_checkers:
                            jc.join()
                            if jc.error:
                                outputs = runners_output_format(runners)
                                raise AutoscaleTimeoutError(
                                    "'{}' timed out on JOIN in {} "
                                    "seconds. The cluster had the following outputs:\n===\n{}"
                                    .format(jc.runner_name, jc.timeout, outputs),
                                    as_error=jc.error,
                                    as_steps=steps)

                    elif joiners < 0:  # joiners < 0, e.g. leavers!
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

                        # Create the checkers

                        initializer = [runners[0]]
                        remaining = [r for r in runners if r.is_alive() and r not
                            in initializer + left]

                        patterns_i = (
                            [r'ExternalChannelConnectNotifier: initializer: '
                             r'server closed',
                             r'Saving topology!',
                             r'Saving worker names to file: .*?initializer.'
                             r'workers'] +
                            [re.escape(r'LocalTopology._save_worker_names: {}'
                                       .format(r.name)) for r in
                                       initializer + remaining] +
                            [re.escape(r'~~~Initiating shrink~~~'),
                             re.escape(r'-- Remaining workers:')] +
                            [re.escape(r'-- -- {}'.format(r.name)) for n in
                             initializer + remaining] +
                            [re.escape(r'~~~Stopping message processing for '
                                       r'leaving workers.~~~'),
                             re.escape(r'~~~Resuming message processing.~~~')])


                        patterns_r = (
                            [re.escape(r'Control Ch: Received Mute Request from initializer'),
                             re.escape(r'~~~Stopping message processing for leaving workers.~~~'),
                             re.escape(r'DataChannelConnectNotifier: server closed'),
                             re.escape(r'ControlSenderConnectNotifier: server closed'),
                             re.escape(r'BoundaryNotify: closed'),
                             re.escape(r'Control Ch: Received Unmute Request from initializer'),
                             re.escape(r'~~~Resuming message processing.~~~'),
                             re.escape(r'Shutting down OutgoingBoundary'),
                             re.escape(r'Shutting down ControlConnection')])
                        patterns_r_per = [
                            r'ControlChannelConnectNotifier:{}: server closed']


                        patterns_l = (
                            [re.escape(r'Control Ch: Received Mute Request from {}'
                                       .format(r.name))
                             for r in initializer + remaining] +
                            [re.escape(r'Migrating all partitions to {} remaining '
                                       r'workers'.format(
                                           len(initializer + remaining))),
                             r'\^\^Migrating \d+ steps to {} workers'
                             .format(len(initializer + remaining))] +
                            [r'\^\^Migrating step \d+ to outgoing '
                             r'boundary {}/[0-9a-f]{{12}}'
                             .format(r.name) for r in initializer + remaining] +
                            [re.escape(r'--Sending leaving worker done migration msg to cluster'),
                             re.escape(r'Connections: Finished shutdown procedure.'),
                             re.escape(r'Shutting down ControlConnection'),
                             re.escape(r'Shutting down TCPSink'),
                             re.escape(r'Shutting down DataReceiver'),
                             re.escape(r'Shutting down ReconnectingMetricsSink'),
                             re.escape(r'Shutting down OutgoingBoundary'),
                             re.escape(r'Shutting down Startup...'),
                             re.escape(r'Shutting down DataChannel'),
                             re.escape(r'metrics connection closed'),
                             re.escape(r'TCPSink connection closed')])
                        patterns_l_per = [
                            r'ControlChannelConnectNotifier:{}: server closed']

                        left_checkers = []

                        # initializer STDOUT checker
                        left_checkers.append(RunnerChecker(initializer[0], patterns_i,
                            timeout=join_timeout,
                            start_from=start_froms[initializer[0]]))

                        # remaining workers STDOUT checkers
                        for runner in remaining:
                            left_checkers.append(RunnerChecker(runner,
                                patterns_r + [p.format(runner.name) for p in
                                              patterns_r_per],
                                timeout=join_timeout,
                                start_from=start_froms[runner]))

                        # leaving workers STDOUT checkers
                        for runner in left:
                            left_checkers.append(RunnerChecker(runner,
                                patterns_l + [p.format(runner.name) for p in
                                              patterns_l_per],
                                timeout=join_timeout,
                                start_from=start_froms[runner]))
                        for lc in left_checkers:
                            lc.start()

                        # Send the shrink command
                        send_shrink_cmd(host, external_port, names=[r.name for r in left])

                        # Wait for output checkers to join
                        for lc in left_checkers:
                            lc.join()
                            if lc.error:
                                outputs = runners_output_format(runners)
                                raise AutoscaleTimeoutError(
                                    "'{}' timed out on SHRINK in {} "
                                    "seconds. The cluster had the following outputs:\n===\n{}"
                                    .format(lc.runner_name, lc.timeout, outputs),
                                    as_error=lc.error,
                                    as_steps=steps)

                    else:  # Handle the 0 case as a noop
                        continue

                    start_froms = {r: r.tell() for r in runners}

                    # Validate autoscale via partition query
                    try:
                        partitions = query_partitions(host, external_port)
                        phase_validate_partitions(runners, partitions,
                                                  joined=[r.name for r in joined],
                                                  left=[r.name for r in left])
                    except Exception as err:
                        print('error validating {} have joined and {} have left'
                              .format([r.name for r in joined],
                                      [r.name for r in left]))
                        raise err

            # wait until sender completes (~10 seconds)
            sender.join(sender_timeout)
            if sender.error:
                raise sender.error
            if sender.is_alive():
                sender.stop()
                raise TimeoutError('Sender did not complete in the expected '
                                   'period')


            # Use Sink value to determine when to stop runners and sink
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
        raise err
