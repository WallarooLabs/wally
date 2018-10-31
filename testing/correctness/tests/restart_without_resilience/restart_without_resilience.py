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
                         runner_data_format,
                         Sender,
                         sequence_generator)
from integration.external import save_logs_to_file
from integration.errors import (RunnerHasntStartedError,
                                SinkAwaitTimeoutError,
                                TimeoutError)
from integration.logger import add_in_memory_log_stream

import datetime
import logging
import os
import re
import struct
import time


FROM_TAIL = int(os.environ.get("FROM_TAIL", 10))


def test_restart_pony():
    command = 'sequence_window'
    _test_restart(command)


def test_restart_machida():
    command = 'machida --application-module sequence_window'
    _test_restart(command)


def test_restart_machida3():
    command = 'machida3 --application-module sequence_window'
    _test_restart(command)


def _test_restart(command):
    t0 = datetime.datetime.now()
    log_stream = add_in_memory_log_stream(level=logging.DEBUG)
    persistent_data = {}
    try:
        try:
            _run(command, persistent_data)
        except:
            logging.error("Restart_without_resilience test encountered an "
                          "error.")
            # Do this ugly thing to use proper exception handling here
            try:
                raise
            except SinkAwaitTimeoutError:
                logging.error("SinkAWaitTimeoutError encountered.")
                raise
            except TimeoutError:
                logging.error("TimeoutError encountered.")
                raise
            except:
                if persistent_data.get('runner_data'):
                    logging.error("Some workers exited badly. The last {} lines of "
                        "each were:\n\n{}"
                        .format(FROM_TAIL,
                            runner_data_format(
                                persistent_data.get('runner_data'),
                                from_tail=FROM_TAIL)))
                raise
    except Exception as err:
        # save log stream to file
        try:
            base_dir = ('/tmp/wallaroo_test_errors/testing/correctness/'
                'tests/restart_without_resilience/{time}'.format(
                    time=t0.strftime('%Y%m%d_%H%M%S')))
            save_logs_to_file(base_dir, log_stream, persistent_data)
        except Exception as err_inner:
            logging.exception(err_inner)
            logging.warn("Encountered an error when saving logs files to {}"
                         .format(base_dir))
        logging.exception(err)
        raise


def _run(command, persistent_data):
    host = '127.0.0.1'
    sources = 1
    sinks = 1
    sink_mode = 'framed'
    workers = 2
    expect = 200
    last_value_0 = '[{}]'.format(','.join((str(expect-v) for v in range(6,-2,-2)))).encode()
    last_value_1 = '[{}]'.format(','.join((str(expect-1-v) for v in range(6,-2,-2)))).encode()
    await_values = (struct.pack('>I', len(last_value_0)) + last_value_0,
                   struct.pack('>I', len(last_value_1)) + last_value_1)


    # Start cluster
    with Cluster(command=command, host=host, sources=sources,
                 workers=workers, sinks=sinks, sink_mode=sink_mode,
                 persistent_data=persistent_data) as cluster:

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
        assert(re.search(pattern_restarting,
                         persistent_data['runner_data'][2].stdout)
               is not None)
    except AssertionError:
        raise AssertionError('Worker does not appear to have reconnected '
                             'as expected. Worker output is '
                             'included below.\nSTDOUT\n---\n%s'
                             % stdout)
