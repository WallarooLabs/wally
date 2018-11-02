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
from integration.errors import (ClusterError,
                                RunnerHasntStartedError)
from integration.external import (run_shell_cmd,
                                  save_logs_to_file)
from integration.integration import pipeline_test
from integration.logger import add_in_memory_log_stream


def run_test(api, cmd, validation_cmd, topology, workers=1):
    max_retries = 5
    t0 = datetime.datetime.now()
    log_stream = add_in_memory_log_stream(level=logging.DEBUG)
    cwd = os.getcwd()
    trunc_head = cwd.find('/wallaroo/') + len('/wallaroo/')
    base_dir = ('/tmp/wallaroo_test_errors/{path}/{api}/{topo}/{workers}'
        '/{timestamp}'.format(
            path=cwd[trunc_head:],
            api=api,
            topo='_'.join(topology),
            workers='{}_workers'.format(workers),
            timestamp=t0.strftime('%Y%m%d_%H%M%S')))
    persistent_data = {}

    steps_val = ' '.join('--{}'.format(s) for s in topology)
    output = 'received.txt'
    cmd_val = ("{cmd} {steps}".format(
                   cmd=cmd,
                   steps=steps_val))
    validation_cmd_val = ("{validation_cmd} {steps} "
                      "--output {output}".format(
                          validation_cmd=validation_cmd,
                          steps=steps_val,
                          output=output))

    # Run the test!
    attempt = 0
    try:
        while True:
            attempt += 1
            try:
                # clean up data collection before each attempt
                persistent_data.clear()
                log_stream.seek(0)
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
                    workers = workers,
                    sources = 1,
                    sinks = 1,
                    mode = 'framed',
                    batch_size = 1,
                    sink_expect = 20,
                    sink_stop_timeout = 5,
                    validate_file = output,
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
            except ClusterError as err:
                outputs = runner_data_format(
                    persistent_data.get('runner_data', []),
                    from_tail=20,
                    filter_fn=lambda r: True)
                logging.error("Worker outputs:\n\n{}\n".format(outputs))
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
        if outputs:
            logging.error("Application outputs:\n{}".format(outputs))
        logging.error("Validation command\n    '%s'\nfailed with the output:\n"
                      "--\n%s",
                      ' '.join(res.command), res.output)
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


def create_test(api, cmd, validation_cmd, steps, workers=1):
    test_name = ('test_{api}_topology_{workers}_workers_{topo}'.format(
        api=api,
        workers=workers,
        topo='_'.join(steps)))
    def f():
        run_test(api, cmd, validation_cmd, steps, workers)
    f.__name__ = test_name
    globals()[test_name] = f

def remove_key_by_chains(steps):
    res = []
    last_step = ''
    for s in steps:
        # There should never be two key_by calls in a row.
        if not ((last_step == 'key-by') and (s == 'key-by')):
            res.append(s)
            last_step = s
    if len(res) == 3:
        # Real pipelines won't end with 'key_by()'.
        if res[2] == 'key-by':
            new_res = []
            new_res.append(res[0])
            new_res.append(res[1])
            res = new_res
    return res

# Create tests!
APIS = {'python': {'cmd': 'machida --application-module app_gen',
                   'validation_cmd': 'python2 app_gen.py'},
       'python3': {'cmd': 'machida3 --application-module app_gen',
                    'validation_cmd': 'python3 app_gen.py'},
       }

# If resilience is on, add --run-with-resilience to commands
import os
if os.environ.get("resilience") == 'on':
    for a in APIS:
        APIS[a]['cmd'] += ' --run-with-resilience'

sizes = [1,2,3]
depth = 3
# COMPS = ['to', 'to-parallel', 'to-stateful', 'to-state-partition']
COMPS = ['to-stateless', 'to-state', 'key-by', 'to-stateless', 'to-state', 'key-by']
# COMPS = ['to', 'key-by']
# COMPS = ['to']
for size in sizes:
    for steps in itertools.chain.from_iterable(
            (itertools.permutations(COMPS, d)
             for d in range(1, depth+1))):
        for api in APIS:
            create_test(api, APIS[api]['cmd'], APIS[api]['validation_cmd'],
                        remove_key_by_chains(steps), size)
