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
import json
import logging
import os
import re
import time

from .cluster import (Cluster,
                     runner_data_format)
from .control import (SinkAwaitValue,
                     SinkExpect)
from .end_points import (ALOSender,
                         Sender,
                         Reader)
from .external import (run_shell_cmd,
                       save_logs_to_file)
from .errors import (PipelineTestError,
                     TimeoutError)
from .logger import INFO2

from wallaroo.experimental.connectors import BaseSource

try:
    basestring
except NameError:
    basestring = (str, bytes)


DEFAULT_SINK_STOP_TIMEOUT = 90
DEFAULT_RUNNER_JOIN_TIMEOUT = 90


FROM_TAIL = int(os.environ.get("FROM_TAIL", 10))


VERSION = '0.0.1'
COOKIE = 'cookie'


def json_keyval_extract(msg):
    d = json.loads(msg[4:].decode())
    key = str(d.get('key'))
    val = d.get('value')
    if isinstance(val, (list,tuple)):
        if all(map(lambda x: isinstance(x, int), val)):
            val = str(val).replace(" ", "")
        else:
            val = str(val)
    else:
        val = str(val)
    return (key, val)


def pipeline_test(sources, expected, command, workers=1,
                  mode='framed', sinks=1, decoder=None, pre_processor=None,
                  batch_size=1, sender_interval=0.001,
                  sink_expect=None, sink_expect_allow_more=False,
                  sink_stop_timeout=DEFAULT_SINK_STOP_TIMEOUT,
                  sink_await=None, sink_await_keys=None, delay=90,
                  output_file=None, validation_cmd=None,
                  host='127.0.0.1', listen_attempts=1,
                  ready_timeout=90,
                  runner_join_timeout=DEFAULT_RUNNER_JOIN_TIMEOUT,
                  resilience_dir=None,
                  spikes={},
                  persistent_data={},
                  log_error=True):
    """
    Run a pipeline test without having to instrument everything
    yourself. This only works for 1-source, 1-sink topologies.

    Parameters:
    - `sources`: either a single (generator, source_name) tuple
        to use in a Sender's Reader,
        or a list of tuples of (generator, source_name) for use with
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
    - `mode`: the decoding mode to use in the sink. Can be `'framed'` or
        `'newlines'`. Default: `'framed'`
    - `sinks`: the number of sinks to set up for the application. Default: 1.
    - `decoder`: an optional decoder to use for decoding the data from the
        sink. Default: None, assume data is strings.
    - `pre_processor`: an optional pre-processor to apply to the entire
        output set before comparing it against the expected data set.
        Default: None, assume output data is directly comparable.
    - `batch_size`: the batch size to use in the sender. Default: 1
    - `sender_interval`: the interval between batch sends in the sender. Default 0.001
    - `sink_expect`: the number of messages to expect at the sink. This allows
        directly relying on received output for timing control. Default: None
        Should be a list of `len(sinks)`.
    - `sink_expect_allow_more`: Bool (default False): allow more messages in sink
        after `sink_expect` values have been received.
    - `sink_await`: a list of (binary) strings to await for at the sink.
        Once all of the await values have been seen at the sink, the test may
        be stopped.
    - `sink_stop_timeout`: the timeout in seconds to use when awaiting an
        expected number of messages at the sink. Raise an error if timeout
        elapses. Default: 90
        Can be a number or a list of numbers of `len(sinks)`.
    - `delay`: Wait for `delay` seconds before stopping the cluster.
      Default 90 seconds. Only used if `sink_expect` and `sink_await`
      are both `None`.
    - `host`: the network host address to use in workers, senders, and
        receivers. Default '127.0.0.1'
    - `listen_attempts`: attempt to start an applicatin listening on ports
        that are provided by the system. After `listen_attempts` fail, raise
        an appropriate error. For tests that experience TCP_WAIT related
        errors, this value should be set higher than 1.
        Default 1.
    - `ready_timeout`: number of seconds before an error is raised if the
        application does not report as ready. Default 90
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
    try:
        # TODO: [Nisan] update this to make sense. This doesn't make sense anymore.
        if sink_expect is not None:
            if not isinstance(sink_expect, (list, tuple)):
                sink_expect = [sink_expect for x in range(sinks)]
            elif len(sink_expect) != sinks:  # list/tuple, but wrong length
                if len(sink_expect) == 1:
                    sink_expect = sink_expect * sinks
                else: # throw error, we don't know how to handle this
                    raise ValueError("sink_expect must be either an integer "
                        "or a list of integers whose length is the same as "
                        "the number of sinks. Got {}."
                        .format(sink_expect))
        elif sink_await is not None:
            if len(sink_await) != sinks:
                sink_await = [sink_await[:] for x in range(sinks)]
        elif sink_await_keys is not None:
            if len(sink_await_keys) != sinks:
                sink_await_keys = [sink_await_keys for x in range(sinks)]

        # figure out source count based on source names
        source_names = list(set([src[1] for src in sources]))

        # Start cluster
        with Cluster(command=command, host=host, sources=source_names,
                     workers=workers, sinks=sinks, sink_mode=mode,
                     worker_join_timeout=runner_join_timeout,
                     is_ready_timeout = ready_timeout,
                     res_dir=resilience_dir,
                     persistent_data=persistent_data) as cluster:

            # Create senders
            if sources:
                if not isinstance(sources, list):
                    sources = [sources]
                for i, (gen, src_name) in enumerate(sources):
                    # TODO [source-migration]: BaseSource is ConnectorBaseSource
                    # should be renamed throughout
                    if isinstance(gen, BaseSource):
                        # AtLeastOnce Sender: ALOSender
                        sender = ALOSender([gen],
                                           VERSION,
                                           COOKIE,
                                           command,
                                           'instance_{}'.format(i),
                                           cluster.source_addrs[0][src_name])
                    else:
                        # plain old TCP sender
                        reader = Reader(gen)
                        # TODO [NH]: figure out how to support sending to workers
                        # other than initializer via command parameters
                        sender = Sender(cluster.source_addrs[0][src_name], reader,
                                        batch_size=batch_size,
                                        interval=sender_interval)
                    cluster.add_sender(sender)

            # start each sender and await its completion before starting the next
            if cluster.senders:
                for sender in cluster.senders:
                    sender.start()
                    sender.join(sink_stop_timeout)
                    if sender.is_alive():
                        raise TimeoutError("Sender {} failed to complete "
                                           "within {} sceonds".format(
                                               sender, sink_stop_timeout))
                    try:
                        assert(sender.error is None)
                    except Exception as err:
                        logging.error("Sender exited with an error")
                        raise sender.error
                logging.debug('All senders completed sending.')
            else:
                logging.debug("No external senders were given for the cluster.")
            # Use sink, metrics, or a timer to determine when to stop the
            # runners and sinks and begin validation
            if sink_expect:
                logging.debug('Waiting for {} messages at the sinks with a timeout'
                              ' of {} seconds'.format(sink_expect,
                                                      sink_stop_timeout))
                for sink, sink_expect_val in zip(cluster.sinks, sink_expect):
                    logging.debug("SinkExpect on {} for {} msgs".format(sink, sink_expect_val))
                    cluster.sink_expect(expected=sink_expect_val,
                                        timeout=sink_stop_timeout,
                                        sink=sink,
                                        allow_more=sink_expect_allow_more)
            elif sink_await:
                logging.debug('Awaiting {} values at the sinks with a timeout of '
                              '{} seconds'.format(sum(map(len, sink_await)),
                                                  sink_stop_timeout))
                for sink, sink_await_vals in zip(cluster.sinks, sink_await):
                    cluster.sink_await(values=sink_await_vals,
                                       timeout=sink_stop_timeout,
                                       sink=sink)
            elif sink_await_keys:
                logging.debug("Awaiting on {} (key,value) pairs with a timeout of "
                              "{} seconds".format(sum(map(len, sink_await_keys)),
                                                  sink_stop_timeout))
                for sink, sink_await_vals in zip(cluster.sinks, sink_await_keys):
                    cluster.sink_await(values=sink_await_vals,
                                       timeout=sink_stop_timeout,
                                       sink=sink,
                                       func=json_keyval_extract)
            else:
                logging.debug('Waiting {} seconds before shutting down '
                              'cluster.'
                              .format(delay))
                time.sleep(delay)

            # join stoppers and check for errors
            cluster.stop_cluster()

            ###############
            # Output file #
            ###############
            if output_file:
                output_files = output_file.split(',')
                for sink, fp in zip(cluster.sinks, output_files):
                    sink.save(fp)
            ############
            # Validation
            ############
            if validation_cmd:
                sink_files = []
                for i, s in enumerate(cluster.sinks):
                    sink_files.extend(s.save(
                        os.path.join(cluster.res_dir, "sink.{}.dat".format(i))))
                with open(os.path.join(cluster.res_dir, "ops.log"), "wt") as f:
                    for op in cluster.ops:
                        f.write("{}\n".format(op))
                command = "{} {}".format(validation_cmd, ",".join(sink_files))
                res = run_shell_cmd(command)
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
                    error = ("Validation command '%s' failed with the output:\n"
                             "--\n%s" % (res.command, res.output))
                    # Save logs to file in case of error
                    raise PipelineTestError(error)

            else:  # compare expected to processed
                logging.debug('Begin validation phase...')
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
                if hasattr(expected, 'read') and hasattr(expected, 'tell'):
                    if isinstance(processed, list):
                        bytesio = io.BytesIO()
                        ## example:
                        ## processed = [{'*': [b'\x00\x00\x00\x18t=6049,data=10,key=HELO\n']}]
                        for a_dictionary in processed:
                            for (key, parts) in a_dictionary.items():
                                if key != '*':
                                    raise Exception('unknown key {} in dict {}'.format(key, a_dictionary))
                                for part in parts:
                                    bytesio.write(part)
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
                        expected = [e + b'\n' for e in expected]
                    try:
                        assert(expected == flattened)
                    except:
                        raise AssertionError("Validation failed. Expected {!r} but"
                                             " received {!r}".format(expected,
                                                                     flattened))
    except:
        if log_error:
            logging.error("Integration pipeline_test encountered an error")
            logging.error("The last {} lines of each worker were:\n\n{}".format(
                FROM_TAIL,
                runner_data_format(persistent_data.get('runner_data', []),
                                   from_tail=FROM_TAIL)))
        raise

    # Return runner names and outputs if try block didn't have a return
    return
