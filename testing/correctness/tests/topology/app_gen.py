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
from collections import (Counter,
                         namedtuple)
import struct

import wallaroo

import components


########################
# Computation base parts
########################

# The Nones stand-in for noop case. E.g.
#       None + to ==> .to()
#       key-by + to ==> .key_by().to()
# For use by topology_test generators:
PRE = [None, 'key-by']
POST = [None, 'filter', 'multi']
COMPS = ['stateless', 'state']
# for internal use:
_PRE = set(map(lambda s: s.replace('-', '_'), filter(None, PRE)))
_POST = set(filter(None, POST))
_COMPS = set(COMPS)

#######################
# Wallaroo functionality
#######################

def parser_add_args(parser):
    parser.add_argument('--stateless', dest='topology', action='append_const',
                        const='stateless')
    parser.add_argument('--state', dest='topology', action='append_const',
                        const='state')
    parser.add_argument('--key-by', dest='topology', action='append_const',
                        const='key_by')
    parser.add_argument('--filter', dest='topology', action='append_const',
                        const='filter')
    parser.add_argument('--multi', dest='topology', action='append_const',
                        const='multi')

def application_setup(args):
    # Parse user options
    parser = argparse.ArgumentParser("Topology Test Generator")
    parser_add_args(parser)
    pargs, _ = parser.parse_known_args(args)

    app_name = "topology test"
    pipe_name = "topology test pipeline"

    print("Using TCP Source")
    in_name, in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    source = wallaroo.TCPSourceConfig(in_host, in_port, in_name, decoder)
    inputs = wallaroo.source(pipe_name, source)

    # programmatically add computations
    topology = Topology(pargs.topology)
    pipeline = topology.build(inputs)

    print("Using TCP Sink")
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    pipeline = pipeline.to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder))
    return wallaroo.build_application(app_name, pipeline)


class Node(object):
    def __init__(self):
        self.comp = None
        self.pre = None
        self.post = None
        self.id = None
        self.post_id = None
        self.pre_id = None

    def __str__(self):
        return ("comp: {}, pre: {}, post: {}, id: {}, post_id: {}, pre_id: {}"
                .format(self.comp, self.pre, self.post, self.id, self.post_id,
                        self.pre_id))

    def is_null(self):
        return (self.comp is None and self.pre is None
                and self.post is None and self.id is None
                and self.post_id is None and self.pre_id is None)


Step = namedtuple('Step', ['key_by', 'node', 'comp', 'tag'])


class Topology(object):
    def __init__(self, cmds):
        print("Topology({!r})".format(cmds))
        c = Counter()
        self.steps = []
        # build topology from cmds in a 2-pass process
        topology = []
        # 1st pass: collapse commands into steps (pre, comp, post)
        current_node = Node()
        for cmd in cmds:
            if cmd in _PRE: # new step
                if not current_node.is_null(): # check this isn't the first cmd
                    topology.append(current_node)
                    current_node = Node()
                c[cmd] += 1
                current_node.pre = cmd
                current_node.pre_id = c[cmd]
            elif cmd in _COMPS: # check if new
                if current_node.comp: # new if node.computation exists
                    topology.append(current_node)
                    current_node = Node()
                c[cmd] += 1
                current_node.comp = cmd
                current_node.id = c[cmd]
            elif cmd in _POST:
                if current_node.post is not None:
                    raise ValueError("Can't have two modifiers in a row. You "
                        "used '--{} --{}'".format(current_node.post, cmd))
                c[cmd] += 1
                current_node.post = cmd
                current_node.post_id = c[cmd]
        # Append the last current_node, since we won't reach another
        # check in the loop for this
        topology.append(current_node)

        # Now build the steps
        for node in topology:
            # configure the node name
            node_name = "{}{}{}".format(('{}{}_'.format(node.pre, node.pre_id)
                                         if node.pre else ''),
                                        '{}{}'.format(node.comp, node.id),
                                        ('_{}{}'.format(node.post, node.post_id)
                                         if node.post else ''))

            # configure node.pre: key_by
            if node.pre == 'key_by':
                key_by = wallaroo.key_extractor(components.key_extractor)
            else:
                key_by = None

            # configure node.post: flow_modifier
            if node.post:
                if node.post == 'multi':
                    # multi: 1-to-2, adding '.x' to msg.key, x in [0,1]
                    # e.g. 1 ->  [1.0, 1.1]
                    flow_mod = components.OneToN(node.post_id, 2)
                elif node.post == 'filter':
                    # filter: filter out keys ending with 1
                    # e.g. 1, 0.1, 1.1, 1.1.1, ...
                    flow_mod = components.FilterBy(node.post_id,
                        lambda msg: msg.key.endswith('1'))
                else:
                    raise ValueError("Invalid flow modifier: {}"
                        .format(node.post))
            else:
                flow_mod = None

            # create the step as a wallaroo wrapped object
            if node.comp == 'stateless':
                f = components.Tag(node_name, flow_mod=flow_mod)
                if node.post == 'multi':
                    comp = wallaroo.computation_multi(f.__name__)(f)
                else:
                    comp = wallaroo.computation(f.__name__)(f)
            elif node.comp == 'state':
                f = components.TagState(node_name, flow_mod=flow_mod)
                if node.post == 'multi':
                    comp = wallaroo.state_computation_multi(f.__name__,
                        components.State)(f)
                else:
                    comp = wallaroo.state_computation(f.__name__,
                        components.State)(f)

            # append the Step object of the computation to self.steps
            self.steps.append(Step(key_by, 'to', comp, f.__name__))

    def build(self, p):
        print("Building topology")
        for step in self.steps:
            # key_by if there is one
            if step.key_by:
                print("Adding key_by")
                p = p.key_by(step.key_by)
            # computation
            print("Adding step: ({!r}, {!r}, {!r})"
                  .format(step.node, step.tag, step.comp))
            p = p.to(step.comp)
        return p


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    # Expecting a 64-bit unsigned int in big endian followed by a string
    val, key = struct.unpack(">Q", bs[:8])[0], bs[8:].decode()
    print("decoded(val: {}, key: {})".format(val, key))
    return components.Message(val, key)


@wallaroo.encoder
def encoder(msg):
    print("encoder({!r})".format(msg))
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

    if not (pargs.topology and pargs.output):
        parser.print_help()
        print('got args: {!r}'.format(sys.argv[1:]))
        parser.exit(1)

    topology = Topology(pargs.topology)
    tags = [step.tag for step in topology.steps]

    while True:
        d = pargs.output.read(4)
        if not d:
            break
        h = struct.unpack('>I', d)[0]
        m = components.Message.decode(pargs.output.read(h))
        try:
            assert(tags == m.tags)
        except AssertionError as err:
            print("Received tags do not match expected.\n"
                  "Received: {!r}\n"
                  "Expected: {!r}".format(m.tags, tags))
            raise err


if __name__ == '__main__':
    validate_api()
