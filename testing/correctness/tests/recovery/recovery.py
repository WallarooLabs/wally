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
                         run_shell_cmd,
                         Reader,
                         runner_data_format,
                         Sender,
                         sequence_generator)
from integration.logger import set_logging

import logging
import os
import re
import struct
import time

set_logging(level=logging.DEBUG)


FROM_TAIL = 10


def test_recovery_pony():
    command = 'sequence_window'
    _test_recovery(command)


def test_recovery_machida():
    command = 'machida --application-module sequence_window'
    _test_recovery(command)


def _test_recovery(command):
    runner_data = []
    try:
        _run(command, runner_data)
    except:
        logging.error("Integration pipeline_test encountered an error")
        logging.error("Some workers exited badly. The last {} lines of "
            "each were:\n\n{}"
            .format(FROM_TAIL,
                runner_data_format(runner_data,
                                   from_tail=FROM_TAIL)))
        raise


def _run(command, runner_data=[]):
    host = '127.0.0.1'
    sources = 1
    sinks = 1
    sink_mode = 'framed'
    workers = 2
    expect = 2000
    last_value_0 = '[{}]'.format(','.join((str(expect-v) for v in range(6,-2,-2))))
    last_value_1 = '[{}]'.format(','.join((str(expect-1-v) for v in range(6,-2,-2))))
    await_values = (struct.pack('>I', len(last_value_0)) + last_value_0,
                   struct.pack('>I', len(last_value_1)) + last_value_1)

    # Start cluster
    with Cluster(command=command, host=host, sources=sources,
                 workers=workers, sinks=sinks, sink_mode=sink_mode,
                 runner_data=runner_data) as cluster:
        # Create sender
        logging.debug("Creating sender")
        sender = Sender(cluster.source_addrs[0],
                        Reader(sequence_generator(expect)),
                        batch_size=100, interval=0.05, reconnect=True)
        cluster.add_sender(sender, start=True)

        # wait for some data to go through the system
        time.sleep(0.2)

        # stop worker in a non-graceful fashion so that recovery files
        # aren't removed
        logging.debug("Killing worker")
        killed = cluster.kill_worker(worker=-1)

        ## restart worker
        logging.debug("Restarting worker")
        cluster.restart_worker(killed)

        # wait until sender completes (~1 second)
        logging.debug("Waiting for sender to complete")
        cluster.wait_for_sender()

        # Wait for the last sent value expected at the worker
        logging.debug("Waiting for sink to complete")
        cluster.sink_await(await_values)

        # stop the cluster
        logging.debug("Stopping cluster")
        cluster.stop_cluster()

        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        out_file = os.path.join(cluster.res_dir, 'received.txt')
        cluster.sinks[0].save(out_file, mode='giles')

        # Validate captured output
        logging.debug("Validating output")
        cmd_validate = ('validator -i {out_file} -e {expect} -a'
                        .format(out_file = out_file,
                                expect = expect))
        res = run_shell_cmd(cmd_validate)
        try:
            assert(res.success)
        except AssertionError:
            raise AssertionError('Output validation failed with the following '
                                 'error:\n{}'.format(res.output))

        # Validate worker actually underwent recovery
        logging.debug("Validating recovery from worker stdout")
        pattern = "RESILIENCE\: Replayed \d+ entries from recovery log file\."
        try:
            assert(re.search(pattern, cluster.runners[-1].get_output()) is not None)
        except AssertionError:
            raise AssertionError("Worker does not appear to have performed "
                                 "recovery as expected.")
