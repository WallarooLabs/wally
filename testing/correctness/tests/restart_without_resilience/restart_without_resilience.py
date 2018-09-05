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
                         Reader,
                         Sender,
                         sequence_generator)
from integration.logger import set_logging

import logging
import re
import struct
import time

set_logging(level=logging.ERROR)


def test_restart_pony():
    command = 'sequence_window'
    _test_restart(command)


def test_restart_machida():
    command = 'machida --application-module sequence_window'
    _test_restart(command)


def _test_restart(command):

    host = '127.0.0.1'
    sources = 1
    sinks = 1
    sink_mode = 'framed'
    workers = 2
    expect = 200
    last_value_0 = '[{}]'.format(','.join((str(expect-v) for v in range(6,-2,-2))))
    last_value_1 = '[{}]'.format(','.join((str(expect-1-v) for v in range(6,-2,-2))))
    await_values = (struct.pack('>I', len(last_value_0)) + last_value_0,
                   struct.pack('>I', len(last_value_1)) + last_value_1)



    runner_data = []
    # Start cluster
    with Cluster(command=command, host=host, sources=sources,
                 workers=workers, sinks=sinks, sink_mode=sink_mode,
                 runner_data=runner_data) as cluster:

        # Create sender
        logging.debug("Creating sender")
        sender = Sender(cluster.source_addrs[0],
                        Reader(sequence_generator(expect)),
                        batch_size=1, interval=0.05, reconnect=True)
        cluster.add_sender(sender, start=True)

        # wait for some data to go through the system
        time.sleep(0.5)

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

    logging.debug("validating restarted worker stdout")
    # Validate worker actually underwent recovery
    pattern_restarting = "Restarting a listener ..."
    try:
        assert(re.search(pattern_restarting, runner_data[2].stdout) is not None)
    except AssertionError:
        raise AssertionError('Worker does not appear to have reconnected '
                             'as expected. Worker output is '
                             'included below.\nSTDOUT\n---\n%s'
                             % stdout)
