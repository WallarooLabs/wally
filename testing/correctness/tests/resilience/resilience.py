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


import datetime
import logging
import math
from numbers import Number
import os
import re
import shutil
import time


# import requisite components for integration test
from integration.integration import (COOKIE,
                                     json_keyval_extract,
                                     VERSION)

from integration.cluster import (Cluster,
                                 runner_data_format)

from integration.end_points import (ALOSender,
                                    ALOSequenceGenerator,
                                    MultiSequenceGenerator,
                                    Reader,
                                    Sender)


from integration.logger import add_in_memory_log_stream

from integration.errors import (RunnerHasntStartedError,
                                SinkAwaitTimeoutError,
                                TimeoutError)

from integration.external import (run_shell_cmd,
                                  save_logs_to_file)


try:
    basestring
except:
    basestring = str

FROM_TAIL = int(os.environ.get("FROM_TAIL", 10))
SAVE_LOGS = True if os.environ.get("SAVE_LOGS", 0) == "1" else False


class SaveLogs(Exception):
    pass

##################
# Helper Functions
##################

def get_await_values(last_sent_groups):
    if _OUTPUT_TYPE == "int":
        return [(str(key), str(val))
                for group in last_sent_groups
                for key, val in group]
    else:
        logging.error(repr(last_sent_groups))
        return [(key,
                 "[{}]".format(",".join(
                     ("{}".format(max(0,x)) for x in range(val-3, val+1)))))
                for group in last_sent_groups
                for key, val in group]


# TODO: refactor and move to control.py
def pause_senders_and_sink_await(cluster, timeout=10):
    logging.debug("pause_senders_and_sink_await")
    if not cluster.senders:
        logging.debug("No senders to pause. Continuing.")
        return
    # we currently only support one type of sender per run
    if not isinstance(cluster.senders[0], Sender):
        return
    cluster.pause_senders()
    for s in cluster.senders:
            logging.debug("Sender paused with {}, and {} bytes in buffer"
                .format(s.reader.gen.seqs, len(s.batch)))
    logging.debug("Waiting for messages to propagate to sink")
    await_values = get_await_values([sender.last_sent() for sender in cluster.senders])
    cluster.sink_await(values=await_values, func=json_keyval_extract)
    # Since snapshots happen at a 1 second frequency, we need to wait
    # more than 1 second to guarantee a snapshot after messages arrived
    logging.debug("All messages arrived at sink!")


class ResilienceOperation(object):
    """
    Baseclass for resilience operation types
    """
    def __init__(self, size, check_size=True):
        if check_size:
            if isinstance(size, int):
                if size <= 0:
                    raise ValueError("size must be a positive integer")
            else:
                raise TypeError("size must be an integer")
        self.size = size

    def sign(self):
        """
        Identify the sign of the operation: e.g. whether it adds or subtracts
        from the total size of the cluster
        >0: 1
        0: 0
        <1: -1
        """
        raise NotImplementedError

    def apply(self, cluster, data=None):
        """
        The logic involved in applying this step and any direct validations
        """
        raise NotImplementedError

    def name(self):
        """
        The name of of the operation, along with its size.
        Useful when printing a history of operations in a concise manner.
        """
        return "{}:{}".format(self.__class__.__name__, self.size)

    def __str__(self):
        return self.name()


class Grow(ResilienceOperation):
    def __init__(self, size, timeout=30, with_test=True):
        super(Grow, self).__init__(size)
        self.timeout = timeout
        self.with_test = with_test

    def sign(self):
        return 1

    def apply(self, cluster, data=None):
        return cluster.grow(by=self.size, timeout=self.timeout,
                            with_test=self.with_test)


class Shrink(ResilienceOperation):
    def __init__(self, workers, timeout=30, with_test=True):
        self.workers = workers
        self.timeout = timeout
        self.with_test = with_test
        if isinstance(workers, basestring):
            super(Shrink, self).__init__(len(workers.split(',')))
        else:
            super(Shrink, self).__init__(workers)

    def sign(self):
        return -1

    def apply(self, cluster, data=None):
        return cluster.shrink(self.workers, timeout=self.timeout,
                              with_test=self.with_test)


class Crash(ResilienceOperation):
    def __init__(self, workers, pause=True):
        if isinstance(workers, (tuple, list)):
            super(Crash, self).__init__(len(workers))
            self.slice = slice(-1, None, 1)
        else:
            super(Crash, self).__init__(workers)
            self.slice = slice(-workers, None, 1)
        self.pause = pause

    def sign(self):
        return -1

    def apply(self, cluster, data=None):
        if self.pause:
            pause_senders_and_sink_await(cluster)
        killed = []
        for w in cluster.workers[self.slice]:
            logging.debug("w is: {}".format(w))
            killed.append(cluster.kill_worker(w))
        return killed


class Recover(ResilienceOperation):
    def __init__(self, size=None, timeout=30, with_test=True, resume=True):
        """
        :size may be a positive int or None
        if int, it denotes the number of workers to recover from the tail end
        of cluster.dead_workers.
        if None, it means recover all workers from the previous step.
        """
        super(Recover, self).__init__(size, check_size=False)
        self.timeout = timeout
        self.with_test = with_test
        self.resume = resume

    def sign(self):
        return 1

    def apply(self, cluster, workers=[]):
        if self.size:
            size = self.size
            # continue below
        elif workers:
            if isinstance(workers, Runner):
                return [cluster.restart_worker(workers)]
            elif isinstance(workers, (tuple, list)):
                return [cluster.restart_worker(w) for w in workers]
            elif isinstance(workers, int):
                size = workers
                # continue below
        else:
            raise ValueError("size or workers must be defined")
        killed = cluster.dead_workers[-size:]
        restarted = cluster.restart_worker(killed)
        if self.with_test:
            cluster.wait_to_resume_processing(timeout=self.timeout)
        if self.resume:
            cluster.resume_senders()
        return restarted


class Wait(ResilienceOperation):
    def __init__(self, seconds):
        if not isinstance(seconds, Number):
            raise TypeError("seconds must be a number")
        super(Wait, self).__init__(seconds, check_size=False)

    def sign(self):
        return 0

    def apply(self, cluster, data=None):
        time.sleep(self.size)
        return data


def lowest_point(ops):
    l = None
    p = 0
    last_size = None
    for o in ops:
        if isinstance(o, Recover):
            if o.size:
                size = o.size
            else:
                size = last_size
        else:
            size = o.size
        p += (size * o.sign())
        if l is None:
            l  = p
        if p < l:
            l = p
    return l


def get_parts(partitions, num):
    """
    Divide a number of partitions over a number of sources,
    With the last source having possibly fewer items.
    """
    parts = []
    size = int(math.ceil(partitions/float(num)))
    for x in range(num):
        parts.append([])
        for v in range(size*x, size*(x+1)):
            if v < partitions:
                parts[-1].append(v)
    return parts

####################################
# Test Runner - Error handler wrapper
####################################


def _test_resilience(command, ops=[], initial=None, source_type='tcp',
                     source_name='Detector', source_number=1,
                     partitions=40, cycles=1, validation_cmd=False,
                     sender_mps=1000, sender_interval=0.01,
                     retry_count=5,
                     api=None):
    """
    Execute a resilience test for the given command.

    `command` - the command string to execute
    `ops` - the list of operations to perform.
    `initial` - (optional) the initial cluster size
    `source_type` - the type of the source ('tcp', 'gensource', 'alo')
    `source_name` - the name of the source (e.g. 'Detector')
    `source_number` - the number of workers to start sources on (default: 1)
    `partitions` - number of partitions to use (default: 40)
    `cycles` - how many times to repeat the list of operations
    `validation_cmd` - The command to use for validation. Default is: False
    `sender_mps` - messages per second to send from the sender (default 1000)
    `sender_interval` - seconds between sender batches (default 0.01)
    `retry_count` - number of times to retry a test after RunnerHasntStartedError
                    (default 5)
    `api` - the string name of the API being tested. Optional, used for naming
            error logs.
    """
    t0 = datetime.datetime.now()
    log_stream = add_in_memory_log_stream(level=logging.DEBUG)
    persistent_data = {}
    res_ops = []
    try:
        try:
            _run(
                persistent_data=persistent_data,
                res_ops=res_ops,
                command=command,
                ops=ops*cycles,
                initial=initial,
                source_type=source_type,
                source_name=source_name,
                source_number=source_number,
                partitions=partitions,
                validation_cmd=validation_cmd,
                sender_mps=sender_mps,
                sender_interval=sender_interval)
        except:
            logging.error("Resilience test encountered an error after the steps"
                          " {}".format([o.name() for o in res_ops]))
            # Do this ugly thing to use proper exception handling here
            try:
                raise
            except RunnerHasntStartedError as err:
                logging.warning("Runner failed to start properly.")
                if retry_count > 0:
                    logging.info("Restarting the test!")
                    _test_resilience(
                        command=command,
                        ops=ops,
                        initial=initial,
                        source_type=source_type,
                        source_name=source_name,
                        source_number=source_number,
                        partitions=partitions,
                        cycles=cycles,
                        validation_cmd=validation_cmd,
                        sender_mps=sender_mps,
                        sender_interval=sender_interval,
                        retry_count=retry_count-1)
                else:
                    logging.error("Max retry attempts reached.")
                    raise
            except SinkAwaitTimeoutError:
                logging.error("SinkAWaitTimeoutError encountered.")
                raise
            except TimeoutError:
                logging.error("TimeoutError encountered.")
                raise
            except:
                crashed_workers = list(
                    filter(lambda r: r.returncode not in (0,-9,-15),
                           persistent_data.get('runner_data')))
                if crashed_workers:
                    logging.error("Some workers exited badly. The last {} lines of "
                        "each were:\n\n{}"
                        .format(FROM_TAIL,
                            runner_data_format(
                                persistent_data.get('runner_data'),
                                from_tail=FROM_TAIL)))
                raise
        else: # no exception
            if SAVE_LOGS:  # raise an error and save logs
                raise SaveLogs()
    except Exception as err:
        # save log stream to file
        try:
            cwd = os.getcwd()
            trunc_head = cwd.find('/wallaroo/') + len('/wallaroo/')
            test_root = '/tmp/wallaroo_test_errors'
            base_dir = ('{test_root}/{head}/{api}/{src_type}/{src_num}/{ops}/{time}'
                .format(
                    test_root=test_root,
                    head=cwd[trunc_head:],
                    api=api,
                    src_type=source_type,
                    src_num=source_number,
                    time=t0.strftime('%Y%m%d_%H%M%S'),
                    ops='_'.join((o.name().replace(':','')
                                  for o in ops*cycles))))
            save_logs_to_file(base_dir, log_stream, persistent_data)
        except Exception as err_inner:
            logging.exception(err_inner)
            logging.warning("Encountered an error when saving logs files to {}"
                         .format(base_dir))
        logging.exception(err)
        raise


#############
# Test Runner
#############

def _run(persistent_data, res_ops, command, ops=[], initial=None,
         source_type='tcp', source_name='Detector', source_number=1,
         partitions=40, validation_cmd=False,
         sender_mps=1000, sender_interval=0.01):
    # set global flag _OUTPUT_TYPE based on application command
    # [TODO] make this less coupled and brittle
    global _OUTPUT_TYPE
    _OUTPUT_TYPE = "int" if "window_detector" in command else "array"

    host = '127.0.0.1'
    sinks = 1
    sink_mode = 'framed'
    batch_size = int(sender_mps * sender_interval)
    logging.debug("batch_size is {batch_size}".format(batch_size = batch_size))

    # If validation_cmd is False, it remains False and no validation is run
    logging.debug("Validation command is: {validation_cmd}".format(validation_cmd = validation_cmd))
    logging.debug("Source_type: {source_type}".format(source_type = source_type))
    logging.debug("source_name: {source_name}".format(source_name = source_name))
    logging.debug("source_number: {source_number}".format(source_number = source_number))
    logging.debug("partitions: {partitions}".format(partitions=partitions))

    if not isinstance(ops, (list, tuple)):
        raise TypeError("ops must be a list or tuple of operations")

    # If no initial workers value is given, determine the minimum number
    # required at the start so that the cluster never goes below 1 worker.
    # If a number is given, then verify it is sufficient.
    if ops:
        if isinstance(ops[0], Recover):
            raise ValueError("The first operation cannot be Recover")
        lowest = lowest_point(ops)
        if lowest < 1:
            min_workers = abs(lowest) + 1
        else:
            min_workers = 1
        if isinstance(initial, int):
            logging.debug('initial: {}'.format(initial))
            logging.debug('min: {}'.format(min_workers))
            assert(initial >= min_workers)
            workers = initial
        else:
            workers = min_workers
    else:  # Test is only for setup using initial workers
        assert(initial > 0)
        workers = initial

    logging.info("Initial cluster size: {}".format(workers))

    parts = get_parts(partitions, source_number)
    sources = []
    if source_type == 'gensource':
        # noop
        command += " --source gensource"
    elif source_type == 'tcp':
        command += " --source tcp"
        # for each part, create a MultiSequenceGenerator with the right base_index
        for part in parts:
            sources.append(MultiSequenceGenerator(base_index=min(part),
                                                  initial_partitions=len(part)))
    elif source_type == 'alo':
        command += " --source alo"
        # for each number in each part, create an ALOSequenceGenerator
        # and group them in groups matching the parts
        for part in parts:
            sources.append([ALOSequenceGenerator("key_{key}".format(key=key), 10000)
                            for key in part])
    else:
        raise ValueError("source_type must be one of ['gensource', 'tcp', 'alo']")

    # Start cluster
    logging.debug("Creating cluster")
    with Cluster(command=command, host=host,
                 sources=[source_name] if source_type != 'gensource' else [],
                 workers=workers, sinks=sinks, sink_mode=sink_mode,
                 persistent_data=persistent_data) as cluster:

        # start senders
        if source_type == 'tcp':
            # All tcp sources connect to initializer, because they don't
            # support shrinking
            for source_gen in sources:
                sender = Sender(cluster.source_addrs[0][source_name],
                    Reader(source_gen),
                    batch_size=batch_size,
                    interval=sender_interval,
                    reconnect=True)
                cluster.add_sender(sender, start=True)
        elif source_type == 'alo':
            for (idx, source_gens) in enumerate(sources):
                sender = ALOSender(source_gens,
                    VERSION,
                    COOKIE,
                    command,
                    "instance_{idx}".format(idx=idx),
                    (cluster.source_addrs[idx % len(cluster.workers)]
                     [source_name]))
                cluster.add_sender(sender, start=True)

        # let the senders send some data first
        time.sleep(1)

        # loop over ops, keeping the result and passing it to the next op
        res = None
        assert(not cluster.get_crashed_workers())
        for op in ops:
            res_ops.append(op)
            logging.info("Executing: {}".format(op))
            res = op.apply(cluster, res)
            assert(not cluster.get_crashed_workers())

        # Wait a full second for things to calm down
        time.sleep(1)

        # If using external senders, wait for them to stop cleanly
        if cluster.senders:
            # Tell the multi-sequence-sender to stop
            cluster.stop_senders()

            # wait for senders to reach the end of their readers and stop
            for s in cluster.senders:
                cluster.wait_for_sender(s)

            # Create await_values for the sink based on the stop values from
            # the multi sequence generator
            await_values = get_await_values([sender.last_sent()
                                             for sender in cluster.senders])
            cluster.sink_await(values=await_values, func=json_keyval_extract)

        logging.info("Completion condition achieved. Shutting down cluster.")

        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        if validation_cmd:
            # TODO: move to validations.py
            out_file = os.path.join(cluster.res_dir, 'received.txt')
            cluster.sinks[0].save(out_file)

            # Validate captured output
            logging.info("Validating output")
            cmd_validate = validation_cmd.format(out_file = out_file)
            res = run_shell_cmd(cmd_validate)
            try:
                assert(res.success)
                logging.info("Validation successful")
            except:
                raise AssertionError('Validation failed with the following '
                                     'error:\n{}'.format(res.output))

        # Validate worker actually underwent recovery
        if cluster.restarted_workers:
            # TODO: move to validations.py
            logging.info("Validating recovery")
            pattern = "RESILIENCE\: Replayed \d+ entries from recovery log file\."
            for r in cluster.restarted_workers:
                stdout = r.get_output()
                try:
                    assert(re.search(pattern, stdout) is not None)
                    logging.info("{} recovered successfully".format(r.name))
                except AssertionError:
                    raise AssertionError('Worker {} does not appear to have performed '
                                         'recovery as expected.'.format(r.name))
