# Copyright 2019 The Wallaroo Authors.
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

import logging
import math
from numbers import Number
import os
from random import Random as _Random
import re
import time

from ..base import (Application,
                    update_dict)


from ..__init__ import root

from integration.end_points import (ALOSender,
                                    ALOSequenceGenerator,
                                    MultiSequenceGenerator,
                                    Reader,
                                    Sender)
from integration.external import (makedirs_if_not_exists,
                                  run_shell_cmd)
from integration.integration import (json_keyval_extract,
                                     COOKIE,
                                     VERSION)

################################
# Resilience Test Applications #
################################

base_resilience_policy = {
    'command_parameters': {
                      'depth': 1,
                      'source': 'tcp',},
    'reconnect': True,
    'sender_interval': 0.01,
    'batch_size': 10,
    'source_number': 1,
    'partitions': 40,
    'version': VERSION,
    'cookie': COOKIE,
    'validation_cmd': ('python3 '
        '{root}/testing/correctness/apps/'
        'multi_partition_detector/_validate.py'
        ' --output {{out_file}}').format(root=root),
    }


try:
    basestring
except:
    basestring = str


def get_await_values(last_sent_groups):
    logging.debug(repr(last_sent_groups))
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
    def __init__(self, size, timeout=90, with_test=True):
        super(Grow, self).__init__(size)
        self.timeout = timeout
        self.with_test = with_test

    def sign(self):
        return 1

    def apply(self, cluster, data=None):
        return cluster.grow(by=self.size, timeout=self.timeout,
                            with_test=self.with_test)


class Shrink(ResilienceOperation):
    def __init__(self, workers, timeout=90, with_test=True):
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
    def __init__(self, size=None, timeout=90, with_test=True, resume=True):
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


class Rotate(ResilienceOperation):
    def __init__(self):
        """
        Trigger a log rotation on all workers using via their external control
        channel.
        """
        super(Rotate, self).__init__(0, check_size=False)

    def sign(self):
        return 0

    def apply(self, cluster, data=None):
        # TODO: Get current last log chunk
        # Use WaitForLogRotation controller in control.py for this.
        rotated = cluster.rotate_logs()
        # TODO: watch for new log chunks to confirm rotation
        return rotated


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


class ResilienceTestBaseApplication(Application):
    name = 'ResilienceTestBaseApplication'

    def __init__(self, config={}, ops=[]):
        super().__init__()
        self.sources = ['Detector']
        self.res_ops = [] # log of ops
        self.ops = ops

        # determine whether there is log rotation in the ops
        self.log_rotation = any(isinstance(op, Rotate) for op in ops)
        logging.info("log_rotation={}".format(self.log_rotation))

        self.config = base_resilience_policy.copy()
        update_dict(self.config, config)
    # If no initial workers value is given, determine the minimum number
    # required at the start so that the cluster never goes below 1 worker.
    # If a number is given, then verify it is sufficient.
        if ops:
            if isinstance(ops[0], Recover):
                raise ValueError("The first operation cannot be Recover")
            lowest = self.lowest_point(ops)
            if lowest < 1:
                min_workers = abs(lowest) + 1
            else:
                min_workers = 1
            self.workers = min_workers

        logging.info("Running {!r} with config {!r}".format(
            self.__class__.name, self.config))

    def run_test_sequence(self):
        self.start_senders()
        self.execute_op_sequence(self.ops)
        self.stop_senders()
        self.validate_output()
        self.validate_recovery()

    def start_senders(self):
        parts = self.get_parts(self.config['partitions'],
                               self.config['source_number'])
        source_gens = []
        if self.config['command_parameters']['source'] == 'tcp':
            # for each part, create a MultiSequenceGenerator with the right base_index
            for part in parts:
                source_gens.append(
                        MultiSequenceGenerator(base_index=min(part),
                                               initial_partitions=len(part)))
        elif self.config['command_parameters']['source'] == 'alo':
            # for each number in each part, create an ALOSequenceGenerator
            # and group them in groups matching the parts
            for part in parts:
                source_gens.append([
                    ALOSequenceGenerator("key_{key}".format(key=key), 10000)
                    for key in part])
        else:
            raise ValueError("source_type must be one of ['tcp', 'alo']")
        self.source_gens = source_gens

        # start senders
        source_name = self.sources[0]
        if self.config['command_parameters']['source'] == 'tcp':
            # All tcp sources connect to initializer, because they don't
            # support shrinking
            for source_gen in self.source_gens:
                sender = Sender(self.cluster.source_addrs[0][source_name],
                    Reader(source_gen),
                    batch_size=self.config['batch_size'],
                    interval=self.config['sender_interval'],
                    reconnect=self.config['reconnect'])
                self.cluster.add_sender(sender, start=True)
        elif self.config['command_parameters']['source'] == 'alo':
            for (idx, source_generators) in enumerate(source_gens):
                sender = ALOSender(source_generators,
                    self.config['version'],
                    self.config['cookie'],
                    self.command,
                    "instance_{idx}".format(idx=idx),
                    (self.cluster.source_addrs[idx % len(self.cluster.workers)]
                     [source_name]))
                self.cluster.add_sender(sender, start=True)

        # let the senders send some data first
        time.sleep(1)

    def execute_op_sequence(self, ops):
        # loop over ops, keeping the result and passing it to the next op
        res = None
        assert(not self.cluster.get_crashed_workers())
        for op in ops:
            self.res_ops.append(op)
            self.cluster.log_op(op)
            logging.info("Executing: {}".format(op))
            res = op.apply(self.cluster, res)
            assert(not self.cluster.get_crashed_workers())

        # Wait a full second for things to calm down
        time.sleep(1)

    def stop_senders(self):
        # If using external senders, wait for them to stop cleanly
        if self.cluster.senders:
            # Tell the multi-sequence-sender to stop
            self.cluster.stop_senders()

            # wait for senders to reach the end of their readers and stop
            for s in self.cluster.senders:
                self.cluster.wait_for_sender(s)

            # Create await_values for the sink based on the stop values from
            # the multi sequence generator
            await_values = get_await_values(
                [sender.last_sent() for sender in self.cluster.senders])
            self.cluster.sink_await(values=await_values,
                                    func=json_keyval_extract)

        logging.info("Completion condition achieved. Shutting down cluster.")

    def validate_output(self):
        # Use validator to validate the data in at-least-once mode
        # save sink data to a file
        if self.config['validation_cmd']:
            # TODO: move to validations.py
            # TODO: This forces _every_ test to save its validated file to artifacts.
            # remove it once the bug with validation failing but passing on the artifact
            # is resolved.
            #out_file = os.path.join(cluster.res_dir, 'received.txt')
            base_path = self.cluster.res_dir
            makedirs_if_not_exists(base_path)
            chars = 'abcdefghijklmnopqrstuvwxyz0123456789'
            rng = _Random()
            random_str = ''.join([rng.choice(chars) for _ in range(8)])
            out_name = 'received_{}.txt'.format(random_str)
            out_file = os.path.join(base_path, out_name)
            logging.info("Saving validation output to {}".format(out_file))
            out_files = self.cluster.sinks[0].save(out_file)

            with open(os.path.join(self.cluster.res_dir, "ops.log"), "wt") as f:
                for op in self.cluster.ops:
                    f.write("{}\n".format(op))

            # Validate captured output
            logging.info("Validating output")
            cmd_validate = self.config['validation_cmd'].format(
                out_file = self.cluster.res_dir)
            res = run_shell_cmd(cmd_validate)
            try:
                assert(res.success)
                logging.info("Validation successful")
                for out_file in out_files:
                    try:
                        os.remove(out_file)
                        logging.info("Removed validation file: {}".format(
                            out_file))
                    except:
                        logging.info("Failed to remove file: {}".format(out_file))
                        pass
            except:
                err = AssertionError('Validation failed with the following '
                                     'error:\n{}'.format(res.output))
                logging.exception(err)
                raise AssertionError("Validation failed")

    def validate_recovery(self):
        # Validate worker actually underwent recovery
        if self.cluster.restarted_workers:
            # TODO: move to validations.py
            logging.info("Validating recovery")
            pattern = r"RESILIENCE\: Replayed \d+ entries from recovery log file\."
            for r in self.cluster.restarted_workers:
                stdout = r.get_output()
                try:
                    assert(re.search(pattern, stdout) is not None)
                    logging.info("{} recovered successfully".format(r.name))
                except AssertionError:
                    raise AssertionError('Worker {} does not appear to have performed '
                                         'recovery as expected.'.format(r.name))


    def lowest_point(self, ops):
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


    def get_parts(self, partitions, num):
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


class MultiPartitionDetectorPony(ResilienceTestBaseApplication):
    name = 'pony_MultiPartitionDetector'
    command = 'multi_partition_detector'


class MultiPartitionDetectorPython2(ResilienceTestBaseApplication):
    name = 'python2_MultiPartitionDetector'
    command = 'machida --application-module multi_partition_detector'


class MultiPartitionDetectorPython3(ResilienceTestBaseApplication):
    name = 'python3_MultiPartitionDetector'
    command = 'machida3 --application-module multi_partition_detector'


