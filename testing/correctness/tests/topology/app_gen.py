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


import argparse
from collections import Counter
import logging
import struct

from integration.logger import (add_in_memory_log_stream,
                                INFO2,
                                set_logging)

import wallaroo

import components


# TODO:
# - [ ] build topology programmatically from args
# - [ ] create validation logic from topology
# - [ ] make this file the runnable validator
#       - e.g. wallaroo runs application_setup(args)
#              validation runs `python app_gen.py --topology ... --output received.txt`
# - [ ] create topos for parity with pony tests. See new_tests.md for details


######################
# Logging functionality
######################

LOG_LEVELS = {'none': 0,
              '1': 1,
              'debug': 10,
              'info': 20,
              'warn': 30,
              'error': 40,
              'critical': 50}

def get_log_level(value):
    """Get the effective log level"""
    return LOG_LEVELS.get(value, 10)


#######################
# Wallaroo functionality
#######################

def parser_add_args(parser):
    parser.add_argument('--to', dest='topology', action='append_const',
                        const='to')
    parser.add_argument('--to-parallel', dest='topology', action='append_const',
                        const='to_parallel')
    parser.add_argument('--to-stateful', dest='topology', action='append_const',
                        const='to_stateful')
    parser.add_argument('--to-state-partition', dest='topology', action='append_const',
                        const='to_state_partition')
    parser.add_argument('--log-level', help=("Set the logging level."),
                           choices=['none', '1', 'debug', 'info', 'warning',
                                    'error', 'critical'],
                           default='info')

def application_setup(args):
    # Parse user options
    parser = argparse.ArgumentParser("Topology Test Generator")
    parser_add_args(parser)
    pargs, _ = parser.parse_known_args(args)

    log_level = get_log_level(pargs.log_level)
    set_logging(name='integration', level=log_level)

    for k, v in pargs._get_kwargs():
        logging.debug('%s: %r' % (k, v))

    app_name = "topology test"
    pipe_name = "topology test pipeline"

    ab = wallaroo.ApplicationBuilder(app_name)

    logging.info("Using TCP Source")
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    source = wallaroo.TCPSourceConfig(in_host, in_port, decoder)

    ab.new_pipeline(pipe_name, source)

    # programmatically add computations
    topology = Topology(pargs.topology)
    ab = topology.build(ab)


    logging.info("Using TCP Sink")
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    ab.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return ab.build()


class Topology(object):
    def __init__(self, topology):
        logging.info("Topology({!r})".format(topology))
        c = Counter()
        self.steps = []
        for node in topology:
            c[node] += 1
            if node == 'to':
                # to
                f = components.Tag('{}{}'.format(node, c[node]))
                comp = wallaroo.computation(f.func_name)(f)
                self.steps.append((node, comp, f.func_name))
            elif node == 'to_stateful':
                # to_stateful
                f = components.TagState('{}{}'.format(node, c[node]))
                comp = wallaroo.state_computation(f.func_name)(f)
                self.steps.append((node, comp, f.func_name))
            elif node == 'to_parallel':

                # to_parallel
                f = components.Tag('{}{}'.format(node, c[node]))
                comp = wallaroo.computation(f.func_name)(f)
                self.steps.append((node, comp, f.func_name))
            elif node == 'to_state_partition':
                # to_state_partition
                f = components.TagState('{}{}'.format(node, c[node]))
                comp = wallaroo.state_computation(f.func_name)(f)
                self.steps.append((node, comp, f.func_name))
            else:
                raise ValueError("Unknown topology node type: {!r}. Please use "
                                 "'to', 'to_parallel', 'to_stateful', or "
                                 "'to_state_partition'".format(node))

    def build(self, ab):
        logging.info("Building topology")
        partition = wallaroo.partition(components.partition)
        for node, comp, tag in self.steps:
            logging.info("Adding step: ({!r}, {!r}, {!r})".format(
                node, tag, comp))
            if node == 'to':
                ab.to(comp)
            elif node == 'to_stateful':
                ab = ab.to_stateful(comp, components.State, tag)
            elif node == 'to_parallel':
                ab = ab.to_parallel(comp)
            elif node == 'to_state_partition':
                ab = ab.to_state_partition(comp, components.State,
                                      tag, partition, [])
        return ab


    # onetomany
    #f = components.Tag(2, flow_mod=components.OneToN(3))
    #comp = wallaroo.computation_multi(f.func_name)(f)
    #ab = ab.to(comp)

    # filter by (only keep key 1.0)
    #f = components.Tag(3, flow_mod=components.FilterBy('key1.0', by=(
    #    lambda data: data.key.endswith('.1') )))
    #comp = wallaroo.computation(f.func_name)(f)
    #ab = ab.to(comp)


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    # Expecting a 64-bit unsigned int in big endian followed by a string
    val, key = struct.unpack(">Q", bs[:8])[0], bs[8:].decode()
    return components.Message(val, key)


@wallaroo.encoder
def encoder(msg):
    s = msg.encode()  # pickled object
    return struct.pack(">I{}s".format(len(s)), len(s), s)


#################
# Validation code
#################

def validate_api():
    parser = argparse.ArgumentParser(prog='Topology App Gen Validator')
    parser.add_argument("--output", type=argparse.FileType("rb"),
                        help="The output from the application.")
    parser_add_args(parser)
    pargs, _ = parser.parse_known_args()

    log_level = get_log_level(pargs.log_level)
    set_logging(name='integration', level=log_level)

    for k, v in pargs._get_kwargs():
        logging.debug('%s: %r' % (k, v))

    topology = Topology(pargs.topology)
    tags = [step[2] for step in topology.steps]

    while True:
        d = pargs.output.read(4)
        if not d:
            break
        h = struct.unpack('>I', d)[0]
        m = components.Message.decode(pargs.output.read(h))
        assert(tags == m.tags)


if __name__ == '__main__':
    validate_api()
