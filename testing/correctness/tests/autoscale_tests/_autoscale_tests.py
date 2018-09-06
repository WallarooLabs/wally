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
from integration import (Cluster,
                         iter_generator,
                         Reader,
                         runner_data_format,
                         Sender)
from integration.logger import set_logging


from collections import Counter
from itertools import cycle
import json
import logging
import os
from string import lowercase
from struct import calcsize, pack, unpack
import time

set_logging()


FROM_TAIL = 10


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


def phase_validate_output(received, expected):
    # Validate captured output
    validate(received, expected)


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
    runner_data = []
    as_steps = []
    try:
        _autoscale_run(command, ops, cycles, initial,
                runner_data, as_steps)
    except Exception as err:
        logging.error("Autoscale test failed after the operations {}."
            .format(as_steps))
        if filter(lambda r: r.returncode not in (0,-9,-15), runner_data):
            logging.error("Some workers exited badly. The last {} lines of "
                "each were:\n\n{}"
                .format(FROM_TAIL if FROM_TAIL > 0 else '-',
                    runner_data_format(runner_data,
                                       from_tail=FROM_TAIL,
                                       filter_fn=lambda r: True)))
        if hasattr(err, 'query_result') and 'PRINT_QUERY' in os.environ:
            logging.error("The test error had the following query result"
                          " attached:\n{}"
                          .format(json.dumps(err.query_result)))
        raise

def _autoscale_run(command, ops=[], cycles=1, initial=None,
        runner_data=[], as_steps=[]):
    host = '127.0.0.1'
    sources = 1
    sinks = 1
    sink_mode = 'framed'

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

    lowercase2 = [a+b for a in lowercase for b in lowercase]
    char_cycle = cycle(lowercase2)
    expected = Counter()
    def count_sent(s):
        expected[s] += 1

    reader = Reader(iter_generator(
        items=char_cycle, to_string=lambda s: pack('>2sI', s, 1),
        on_next=count_sent))

    # Start cluster
    logging.debug("Creating cluster")
    with Cluster(command=command, host=host, sources=sources,
                 workers=workers, sinks=sinks, sink_mode=sink_mode,
                 runner_data=runner_data) as cluster:

        # Create sender
        logging.debug("Creating sender")
        sender = Sender(cluster.source_addrs[0],
                        reader,
                        batch_size=50, interval=0.05, reconnect=True)
        cluster.add_sender(sender, start=True)
        # wait for some data to go through the system
        time.sleep(1)

        # Perform autoscale cycles
        logging.debug("Starting autoscale cycles")
        for cyc in range(cycles):
            for joiners in ops:
                # Verify cluster is processing before proceeding
                cluster.wait_to_resume_processing(timeout=120)

                # Test for crashed workers
                assert(not cluster.get_crashed_workers())

                # get partition data before autoscale operation begins
                logging.debug("Get partition data before autoscale event")
                pre_partitions = cluster.get_partition_data()
                as_steps.append(joiners)
                joined = []
                left = []

                if joiners > 0:  # autoscale: grow
                    # create new workers and have them join
                    logging.debug("grow by {}".format(joiners))
                    joined = cluster.grow(by=joiners)

                elif joiners < 0:  # autoscale: shrink
                    # choose the most recent, still-alive runners to leave
                    leavers = abs(joiners)
                    left = cluster.shrink(leavers)

                else:  # Handle the 0 case as a noop
                    continue

                # Wait until all live workers report 'ready'
                cluster.wait_to_resume_processing(timeout=120)

                # Test for crashed workers
                assert(not cluster.get_crashed_workers())

                # Wait a second before the next operation, allowing some
                # more data to go through the system
                time.sleep(1)
                logging.debug("end of autoscale iteration")
            logging.debug("End of autoscale cycle")
        logging.debug("End of autoscale events. Entering final validation")
        time.sleep(2)

        # Test for crashed workers
        logging.debug("check for crashed")
        assert(not cluster.get_crashed_workers())

        # Test is done, so stop sender
        cluster.stop_senders()

        # wait until sender sends out its final batch and exits
        cluster.join_sender()

        logging.info('Sender sent {} messages'.format(sum(expected.values())))

        # Use Sink value to determine when to stop runners and sink
        pack677 = '>I2sQ'
        await_values = [pack(pack677, calcsize(pack677)-4, c, v) for c, v in
                        expected.items()]
        cluster.sink_await(await_values, timeout=120)

        # validate output
        phase_validate_output(cluster.sinks[0].data, expected)
