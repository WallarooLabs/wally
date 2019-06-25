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
import os
import time

from ..__init__ import root  # absolute path for Wallaroo repo

from ..base import (Application,
                    update_dict)
from ..completes_when import data_in_sink_count_is

from integration.cluster import runner_data_format
from integration.end_points import (Reader,
                                    Sender,
                                    sequence_generator)
from integration.errors import TimeoutError
from integration.external import run_shell_cmd

########################
# Topology Testing App #
########################
base_topology_policy = {
    'command_parameters': {},
    'sender_interval': 0.01,
    'batch_size': 10,
    'workers': 1,
    'topology': [],}


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


class TopologyTestError(Exception):
    pass


class TopologyTesterBaseApp(Application):
    name = 'TopologyTestingBaseApp'
    command = None
    validation_command = None
    sources = ['topology_tester']
    split_streams = False

    def __init__(self, config={}):
        super().__init__()
        self.config = base_topology_policy.copy()
        update_dict(self.config, config)
        self.workers = self.config['workers']
        self.topology = self.config['topology']
        # Add steps from topology to command and validation_command
        steps_val = ' '.join('--{}'.format(s) for s in self.topology)

        self.command = ("{cmd} {steps}".format(
                       cmd=self.command,
                       steps=steps_val))
        self.validation_command = (
                "{validation_cmd} {steps} "
                "--output {{output}}".format(
                    validation_cmd=self.validation_command,
                    steps=steps_val))

        expect_mod = get_expect_modifier(self.topology)
        logging.info("Expect mod is {} for topology {!r}".format(expect_mod,
            self.topology))
        send, expect = find_send_and_expect_values(expect_mod)
        self.expect = expect
        logging.info("Sending {} messages per key".format(send))
        logging.info("Expecting {} final messages per key".format(expect))
        logging.info("Running {!r} with config {!r}".format(
            self.__class__.name, self.config))

        self.source_gens = [(sequence_generator(send, 0, '>I', 'key_0'),
                             'topology_tester'),
                            (sequence_generator(send, 0, '>I', 'key_1'),
                             'topology_tester')]

    def start_senders(self):
        logging.info("Starting senders")
        src_name = self.sources[0]
        for gen, src_name in self.source_gens:
            sender = Sender(address = self.cluster.source_addrs[0][src_name],
                            reader = Reader(gen))
            self.cluster.add_sender(sender, start=True)
        logging.debug("end of send_tcp")

    def join_senders(self):
        logging.info("Joining senders")
        for sender in self.cluster.senders:
            sender.join(self.sender_join_timeout)
            if sender.error:
                raise sender.error
            if sender.is_alive():
                raise TimeoutError("Sender failed to join in {} seconds"
                        .format(self.sender_join_timeout))

    def sink_await(self):
        logging.info("Awaiting on sink")
        self.completes_when(data_in_sink_count_is(
            expected=(len(self.source_gens) * self.expect),
            timeout=30,
            sink=-1,
            allow_more=False))

    def validate(self):
        logging.info("Validating output")
        sink_files = []
        for i, s in enumerate(self.cluster.sinks):
            sink_files.extend(s.save(
                os.path.join(self.cluster.log_dir, "sink.{}.dat".format(i))))
        with open(os.path.join(self.cluster.log_dir, "ops.log"), "wt") as f:
            for op in self.cluster.ops:
                f.write("{}\n".format(op))
        command = self.validation_command.format(output = ",".join(sink_files))
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
            outputs = runner_data_format(self.persistent_data.get('runner_data',
                                                                  []))
            if outputs:
                logging.error("Application outputs:\n{}".format(outputs))
            error = ("Validation command '%s' failed with the output:\n"
                     "--\n%s" % (' '.join(res.command), res.output))
            # Save logs to file in case of error
            raise TopologyTestError(error)


class TopologyTesterPython2(TopologyTesterBaseApp):
    name = 'python2_TopologyTester'
    command = 'machida --application-module topology_tester'
    validation_command = ('python2 '
        '{root}/testing/correctness/apps/'
        'topology_tester/topology_tester.py').format(root=root)


class TopologyTesterPython3(TopologyTesterBaseApp):
    name = 'python3_TopologyTester'
    command = 'machida3 --application-module topology_tester'
    validation_command = ('python3 '
        '{root}/testing/correctness/apps/'
        'topology_tester/topology_tester.py').format(root=root)
