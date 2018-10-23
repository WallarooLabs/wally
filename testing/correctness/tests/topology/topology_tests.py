#
# Copyright 2018 The Wallaroo Authors.
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
#


import datetime
import itertools
import logging
import os
import time

from integration.cluster import runner_data_format
from integration.end_points import sequence_generator
from integration.errors import RunnerHasntStartedError
from integration.external import (run_shell_cmd,
                                  save_logs_to_file)
from integration.integration import pipeline_test
from integration.logger import add_in_memory_log_stream

from app_gen import LOG_LEVELS

LEVEL_LOGS = {v: k for k, v in LOG_LEVELS.items()}


def run_test(cmd, validation_cmd, topology):
    max_retries = 5
    t0 = datetime.datetime.now()
    log_stream = add_in_memory_log_stream(level=logging.DEBUG)
    cwd = os.getcwd()
    trunc_head = cwd.find('/wallaroo/') + len('/wallaroo/')
    base_dir = '/tmp/wallaroo_test_errors/{}/{}/{}'.format(
        cwd[trunc_head:],
        '_'.join('--{}'.format(api) for api in topology),
        t0.strftime('%Y%m%d_%H%M%S'))
    persistent_data = {}

    log_level = LEVEL_LOGS.get(logging.root.level, 'none')
    steps_val = ' '.join('--{}'.format(s) for s in topology)
    cmd_val = ("{cmd} --log-level {log_level} {steps}".format(
                   cmd=cmd,
                   log_level=log_level,
                   steps=steps_val))
    validation_cmd_val = ("{validation_cmd} --log-level {log_level} {steps} "
                      "--output".format(
                          validation_cmd=validation_cmd,
                          log_level=log_level,
                          steps=steps_val))

    # Run the test!
    attempt = 0
    try:
        while True:
            attempt += 1
            try:
                # clean up data collection before each attempt
                persistent_data.clear()
                log_stream.reset()
                log_stream.truncate()

                # start test attempt
                logging.info("Integration test attempt {}".format(attempt))
                logging.debug("Running integration test with the following"
                              " options:")

                gens = [(sequence_generator(10, 0, '>I', 'key_0'), 0),
                        (sequence_generator(10, 0, '>I', 'key_1'), 0)]

                pipeline_test(
                    generator = gens,
                    expected = None,
                    command = cmd_val,
                    workers = 1,
                    sources = 1,
                    sinks = 1,
                    mode = 'framed',
                    batch_size = 1,
                    sink_expect = 20,
                    validate_file = 'received.txt',
                    persistent_data = persistent_data)
                # Test run was successful, break out of loop and proceed to
                # validation
                logging.info("Run phase complete. Proceeding to validation.")
                break
            except RunnerHasntStartedError:
                logging.warn("Runner failed to start properly.")
                if attempt < max_retries:
                    logging.info("Restarting the test!")
                    time.sleep(0.5)
                    continue
                else:
                    logging.error("Max retry attempts reached.")
                    raise
            except:
                raise
    except Exception as err:
        logging.exception("Encountered an error while running the test for"
                          " %r\n===\n" % cmd)
        # Save logs to file in case of error
        try:
            save_logs_to_file(base_dir, log_stream, persistent_data)
        except Exception as err:
            logging.warn("failed to save logs to file")
            logging.exception(err)
        raise

    res = run_shell_cmd(validation_cmd_val)
    if res.success:
        if res.output:
            logging.info("Validation command '%s' completed successfully "
                         "with the output:\n--\n%s", ' '.join(res.command),
                                                              res.output)
        else:
            logging.info("Validation command '%s' completed successfully",
                         ' '.join(res.command))
    else:
        outputs = runner_data_format(persistent_data.get('runner_data', []))
        logging.error("Application outputs:\n{}".format(outputs))
        logging.error("Validation command '%s' failed with the output:\n"
                      "--\n%s",
                      res.command, res.output)
        # Save logs to file in case of error
        save_logs_to_file(base_dir, log_stream, persistent_data)

        if logging.root.level > logging.ERROR:
            # If failed, and logging level means we didn't log error, include it
            # in exit message
            print(res.output)
            exit(res.return_code)

    # Reached the end and nothing broke. Success!
    logging.info("Topology test completed successfully for topology {!r}"
                 .format(topology))


def create_test(api, cmd, validation_cmd, steps):
    test_name = 'test_topology_{}_{}'.format(api, '_'.join(steps))
    def f():
        run_test(cmd, validation_cmd, steps)
    f.func_name = test_name
    globals()[test_name] = f

# Create tests!
APIS = {'python': {'cmd': 'machida --application-module app_gen',
                   'validation_cmd': 'python2 app_gen.py'},}
        #'python3': {'cmd': 'machida3 --application-module app_gen',
        #            'validation_cmd': 'python2 app_gen.py'}}

# If resilience is on, add --run-with-resilience to commands
import os
if os.environ.get("resilience") == 'on':
    for a in APIS:
        APIS[a]['cmd'] += ' --run-with-resilience'

COMPS = ['to', 'to-parallel', 'to-stateful', 'to-state-partition']
for steps in itertools.combinations_with_replacement(COMPS, 3):
    for api in APIS:
        create_test(api, APIS[api]['cmd'], APIS[api]['validation_cmd'], steps)
