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

from app_gen import (COMPS,
                     POST,
                     PRE)


from integration.cluster import runner_data_format
from integration.end_points import sequence_generator
from integration.errors import (ClusterError,
                                RunnerHasntStartedError,
                                ValidationError)
from integration.external import (run_shell_cmd,
                                  save_logs_to_file)
from integration.integration import pipeline_test
from integration.logger import add_in_memory_log_stream


SINK_EXPECT_MODIFIER = {'filter': 0.5, 'multi': 2}

def get_expect_modifier(topology):
    last = topology[0]
    expect_mod = SINK_EXPECT_MODIFIER.get(last, 1)
    for s in topology[1:]:
        # successive filters don't reduce because the second filter only
        # receives input that already passed the first filter
        if not s in SINK_EXPECT_MODIFIER:
            continue
        if s == 'filter' and s == last:
            continue
        expect_mod *= SINK_EXPECT_MODIFIER[s]
        last = s
    return expect_mod


def find_send_and_expect_values(expect_mod, min_expect=20):
    send = 10
    while True:
        if ((int(send * expect_mod) == send * expect_mod) and
            send * expect_mod >= min_expect):
            break
        else:
            send += 1
    return (send, int(send * expect_mod))


def run_test(api, cmd, validation_cmd, topology, workers=1):
    max_retries = 3
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

    expect_mod = get_expect_modifier(topology)
    logging.info("Expect mod is {} for topology {!r}".format(expect_mod, topology))
    send, expect = find_send_and_expect_values(expect_mod)
    logging.info("Sending {} messages per key".format(send))
    logging.info("Expecting {} final messages per key".format(expect))

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

                sources = [(sequence_generator(send, 0, '>I', 'key_0'),
                            "'topology test pipeline'"),
                           (sequence_generator(send, 0, '>I', 'key_1'),
                            "'topology test pipeline'")]

                pipeline_test(
                    sources = sources,
                    expected = None,
                    command = cmd_val,
                    workers = workers,
                    sinks = 1,
                    mode = 'framed',
                    batch_size = 1,
                    sink_expect = expect * len(sources),
                    sink_stop_timeout = 5,
                    output_file = output,
                    persistent_data = persistent_data,
                    log_error = False)
                # Test run was successful, break out of loop and proceed to
                # validation
                logging.info("Run phase complete. Proceeding to validation.")
                break
            except RunnerHasntStartedError:
                logging.warning("Runner failed to start properly.")
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
                outputs = runner_data_format(
                    persistent_data.get('runner_data', []),
                    from_tail=20)
                if outputs:
                    logging.error("Worker outputs:\n\n{}\n".format(outputs))
                raise
    except Exception as err:
        logging.exception("Encountered an error while running the test for"
                          " %r\n===\n" % cmd)
        # Save logs to file in case of error
        try:
            save_logs_to_file(base_dir, log_stream, persistent_data)
        except Exception as err:
            logging.warning("failed to save logs to file")
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
        logging.error("Validation command\n    '{}'\nfailed with the output:\n"
                      "--\n{}".format(' '.join(res.command), res.output))
        # Save logs to file in case of error
        save_logs_to_file(base_dir, log_stream, persistent_data)

        if logging.root.level > logging.ERROR:
            # If failed, and logging level means we didn't log error, include it
            # in exit message
            print(res.output)
            exit(res.return_code)
        raise ValidationError()

    # Reached the end and nothing broke. Success!
    logging.info("Topology test completed successfully for topology {!r}"
                 .format(topology))
    del persistent_data
    log_stream.close()
    logging.root.handlers.clear()
    del log_stream
    time.sleep(0.1)


def create_test(api, cmd, validation_cmd, steps, workers=1):
    test_name = ('test_{api}_topology_{workers}_workers_{topo}'.format(
        api=api,
        workers=workers,
        topo='_'.join(steps)))
    def f():
        run_test(api, cmd, validation_cmd, steps, workers)
    f.__name__ = test_name
    globals()[test_name] = f
    return f


# Create tests!
APIS = {'python2': {'cmd': 'machida --application-module app_gen',
                   'validation_cmd': 'python2 app_gen.py'},
       'python3': {'cmd': 'machida3 --application-module app_gen',
                    'validation_cmd': 'python3 app_gen.py'},
       }

# If resilience is on, add --run-with-resilience to commands
import os
if os.environ.get("resilience") == 'on':
    for a in APIS:
        APIS[a]['cmd'] += ' --run-with-resilience'


# Cluster sizes
sizes = [1, 2, 3]
# Maximum topology depth
depth = 3

# Create basis set of steps from fundamental components
# TODO: enable tests with POST computation modifiers (filter,multi)
#prods = list(itertools.product(PRE, COMPS, POST))
prods = list(itertools.product(PRE, COMPS))

# eliminate Nones from individual tuples
filtered = list(map(tuple, [filter(None, t) for t in prods]))
# sort by length of tuple, then alphabetical order of tuple members
basis_steps = list(sorted(filtered, key=lambda v: (len(v), v)))

# Create topology sequences
sequences = []
for steps in itertools.chain.from_iterable(
            (itertools.product(basis_steps, repeat=d)
             for d in range(1, depth+1))):
                sequences.append((list(itertools.chain.from_iterable(steps))))

# Create tests for size and api combinations
tests_count = 0
for size in sizes:
    for api in APIS:
        for seq in sequences:
            create_test(api, APIS[api]['cmd'], APIS[api]['validation_cmd'],
                        seq, size)
            tests_count += 1


if __name__ == '__main__':
    print("Basis steps:")
    for x in basis_steps:
        print(x)
    print('---')
    print("Number of basis steps: {}".format(len(basis_steps)))
    print("Cluster sizes: {}".format(sizes))
    print("Topology depths: {}".format(list(range(1, depth+1))))
    print("APIs: {}".format(APIS.keys()))
    print("Number of tests per API: {}".format(len(sequences)))
    print("Total number of tests: {}".format(len(APIS) * len(sequences) * len(sizes)))
    print("Actual number of tests: {}".format(tests_count))
