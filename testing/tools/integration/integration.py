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


from collections import namedtuple
import io
import itertools
import logging
import re
import time

from cluster import (Cluster,
                     runner_data_format)
from control import (SinkAwaitValue,
                     SinkExpect)
from end_points import (Sender,
                        Reader)
from errors import PipelineTestError
from logger import INFO2



DEFAULT_SINK_STOP_TIMEOUT = 30
DEFAULT_RUNNER_JOIN_TIMEOUT = 30


def pipeline_test(generator, expected, command, workers=1, sources=1,
                  mode='framed', sinks=1, decoder=None, pre_processor=None,
                  batch_size=1, sink_expect=None,
                  sink_stop_timeout=DEFAULT_SINK_STOP_TIMEOUT,
                  sink_await=None, delay=30,
                  validate_file=None, giles_mode=False,
                  host='127.0.0.1', listen_attempts=1,
                  ready_timeout=30,
                  runner_join_timeout=DEFAULT_RUNNER_JOIN_TIMEOUT,
                  resilience_dir=None,
                  spikes={}):
    """
    Run a pipeline test without having to instrument everything
    yourself. This only works for 1-source, 1-sink topologies.

    Parameters:
    - `generator`: either a single data generator to use in a Sender's Reader,
        or a list of tuples of (generator, source_index) for use with
        multi-source applications. In the latter case, the senders are run
        sequentially, and the index is 0-based against the input addresses.
        the values in this set should be either strings or stringable. If they
        are custom data structures, they should already be encoded as strings.
    - `expectd`: the expect output set, to be compared against the received
        output. The data should be directly comparable to the decoded output.
    - `command`: the command to run each worker. Make sure to leave out the
        Wallaroo parameters: `--in`, `--out`, `--metrics`, `--data`,
        `--control`, `--external`, `--workers`, `--name`,
        `--cluster-initializer`, and `--ponynoblock`.
        These will be applied by the test setup utility.
    - `workers`: the number of workers to use in the test. Default: 1.
    - `sources`: the number of sources in the application. Default: 1.
    - `mode`: the decoding mode to use in the sink. Can be `'framed'` or
        `'newlines'`. Default: `'framed'`
    - `sinks`: the number of sinks to set up for the application. Default: 1.
    - `decoder`: an optional decoder to use for decoding the data from the
        sink. Default: None, assume data is strings.
    - `pre_processor`: an optional pre-processor to apply to the entire
        output set before comparing it against the expected data set.
        Default: None, assume output data is directly comparable.
    - `batch_size`: the batch size to use in the sender. Default: 1
    - `sink_expect`: the number of messages to expect at the sink. This allows
        directly relying on received output for timing control. Default: None
        Should be a list of `len(sinks)`.
    - `sink_await`: a list of (binary) strings to await for at the sink.
        Once all of the await values have been seen at the sink, the test may
        be stopped.
    - `sink_stop_timeout`: the timeout in seconds to use when awaiting an
        expected number of messages at the sink. Raise an error if timeout
        elapses. Default: 30
        Can be a number or a list of numbers of `len(sinks)`.
    - `delay`: Wait for `delay` seconds before stopping the cluster.
      Default 30 seconds. Only used if `sink_expect` and `sink_await`
      are both `None`.
    - `validate_file`: save sink data to a file to be validated by an external
        process.
    - `giles_mode`: if True, include a 64-bit timestamp between the length
        header and the payload when saving sink data to file. This is a
        backward compatibility mode for validators that expected
        giles-receiver format.
    - `host`: the network host address to use in workers, senders, and
        receivers. Default '127.0.0.1'
    - `listen_attempts`: attempt to start an applicatin listening on ports
        that are provided by the system. After `listen_attempts` fail, raise
        an appropriate error. For tests that experience TCP_WAIT related
        errors, this value should be set higher than 1.
        Default 1.
    - `ready_timeout`: number of seconds before an error is raised if the
        application does not report as ready. Default 30
    - `runner_join_timeout`: the timeout in seconds to use when waiting for
      the runners to exit cleanly. If the timeout is exceeded, the runners
      are killed and an error is raised.
    - `resilience_dir`: The directory where resilience file are kept. This
        path will be cleaned up before and after each run.
    - `spikes`: A dict of 3-tuples with the worker index as its key, and
        the spike parameters (probability, margin, seed) as its value.

    `expected` and the processed sink(s) data should be directly equatable.
    The test fails if they fail an equality assertion.
    If multiple sinks are used, then expected should match the flattened
    list of procssed sinks` data.
    e.g. if there are 2 sinks with the data [1,1,1] and [2,2,2] respectively,
    then expected should be [1,1,1,2,2,2].
    """
    runner_data = []
    try:
        if sink_expect is not None:
            if not isinstance(sink_expect, (list, tuple)):
                sink_expect = [sink_expect for x in range(sinks)]
        elif sink_await is not None:
            if len(sink_await) != sinks:
                sink_await = [sink_await[:] for x in range(sinks)]

        # Start cluster
        with Cluster(command=command, host=host, sources=sources,
                     workers=workers, sinks=sinks, sink_mode=mode,
                     worker_join_timeout=runner_join_timeout,
                     is_ready_timeout = ready_timeout,
                     res_dir=resilience_dir,
                     runner_data=runner_data) as cluster:

            # Create senders
            senders = []
            if not isinstance(generator, list):
                generator = [(generator, 0)]
            for gen, idx in generator:
                reader = Reader(gen)
                sender = Sender(cluster.source_addrs[idx], reader,
                                batch_size=batch_size)
                cluster.add_sender(sender)

            # start each sender and await its completion before startin the next
            for sender in cluster.senders:
                sender.start()
                sender.join()
                try:
                    assert(sender.error is None)
                except Exception as err:
                    logging.error("Sender exited with an error")
                    raise sender.error
            logging.debug('All senders completed sending.')
            # Use sink, metrics, or a timer to determine when to stop the
            # runners and sinks and begin validation
            stoppers = []
            if sink_expect:
                logging.debug('Waiting for {} messages at the sinks with a timeout'
                              ' of {} seconds'.format(sink_expect,
                                                      sink_stop_timeout))
                for sink, sink_expect_val in zip(cluster.sinks, sink_expect):
                    stopper = SinkExpect(sink, sink_expect_val, sink_stop_timeout)
                    stopper.start()
                    stoppers.append(stopper)
            elif sink_await:
                logging.debug('Awaiting {} values at the sinks with a timeout of '
                              '{} seconds'.format(sum(map(len, sink_await)),
                                                  sink_stop_timeout))
                stoppers = []
                for sink, sink_await_vals in zip(cluster.sinks, sink_await):
                    stopper = SinkAwaitValue(sink, sink_await_vals,
                                             sink_stop_timeout)
                    stopper.start()
                    stoppers.append(stopper)
            else:
                logging.debug('Waiting {} seconds before shutting down '
                              'cluster.'
                              .format(delay))
                time.sleep(delay)

            # join stoppers and check for errors
            for stopper in stoppers:
                stopper.join()
                if stopper.error:
                    print(cluster.sinks)
                    for s in cluster.sinks:
                        print
                        print(len(s.data))
                        print()
                    raise stopper.error
            logging.debug('Shutting down cluster.')

            cluster.stop_cluster()

            ############
            # Validation
            ############
            logging.debug('Begin validation phase...')
            # Use initializer's outputs to validate topology is set up correctly
            check_initializer = re.compile(r'([\w\d]+) worker topology')
            stdout = cluster.runners[0].get_output()
            try:
                m = check_initializer.search(stdout)
                assert(m is not None)
                topo_type = m.group(1)
                if topo_type.lower() == 'single':
                    topo_type = 1
                else:
                    topo_type = int(topo_type)
                assert(workers == topo_type)
            except Exception as err:
                print 'runner output'
                print stdout
                raise

            if validate_file:
                validation_files = validate_file.split(',')
                for sink, fp in zip(cluster.sinks, validation_files):
                    sink.save(fp, giles_mode)
                # let the code after 'finally' return our data

            else:  # compare expected to processed
                # Decode captured output from sink
                if decoder:
                    if not isinstance(decoder, (list, tuple)):
                        decoder = [decoder for s in cluster.sinks]
                    decoded = []
                    for sink, decoder in zip(cluster.sinks, decoder):
                        decoded.append([])
                        for item in sink.data:
                            decoded[-1].append(decoder(item))
                else:
                    decoded = [sink.data for sink in cluster.sinks]

                if pre_processor:
                    processed = pre_processor(decoded)
                else:
                    processed = decoded

                # Validate captured output against expected output
                if isinstance(expected, basestring):
                    expected = io.BufferedReader(io.BytesIO(expected))
                if isinstance(expected, (file, io.BufferedReader)):
                    if isinstance(processed, list):
                        bytesio = io.BytesIO()
                        for part in processed:
                            for p in part:
                                bytesio.write(p)
                        bytesio.seek(0)
                        processed = io.BufferedReader(bytesio)
                    elif isinstance(processed, basestring):
                        processed = io.BufferedReader(io.BytesIO(processed))
                    # compare 50 bytes at a time
                    while True:
                        start_block = expected.tell()
                        proc = processed.read(50)
                        exp = expected.read(50)
                        if not proc and not exp:
                            break
                        try:
                            assert(exp == proc)
                        except:
                            raise AssertionError("Validation failed in bytes {}:{}"
                                                 " of expected file. Expected {!r}"
                                                 " but received {!r}.".format(
                                                     start_block,
                                                     expected.tell(),
                                                     exp,
                                                     proc))
                else:
                    flattened = list(itertools.chain.from_iterable(processed))
                    if mode == 'newlines':
                        # add newlines to expected
                        expected = ['{}\n'.format(e) for e in expected]
                    try:
                        assert(expected == flattened)
                    except:
                        raise AssertionError("Validation failed. Expected {!r} but"
                                             " received {!r}".format(expected,
                                                                     processed))
    except:
        logging.error("Integration pipeline_test encountered an error")
        logging.error("The last 10 lines of each worker were:\n\n{}".format(
            runner_data_format(runner_data, from_tail=10)))
        raise

    # Return runner names and outputs if try block didn't have a return
    return_value = [(rd.name, rd.stdout) for rd in runner_data]
    return return_value
