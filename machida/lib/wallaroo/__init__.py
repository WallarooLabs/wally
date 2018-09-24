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


import argparse
import pickle
import struct
import inspect
import sys

import wallaroo.experimental

def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


class WallarooParameterError(Exception):
    pass


class ApplicationBuilder(object):
    def __init__(self, name):
        self._connectors = {}
        self._next_source_connector_port = 7100
        self._next_sink_connector_port = 7200
        self._actions = [("name", name)]

    def new_pipeline(self, name, source_config):
        if isinstance(source_config, wallaroo.experimental.SourceConnectorConfig):
            self._connectors[source_config._name] = source_config
            if source_config._is_unassigned():
                source_config._assign('127.0.0.1', self._next_source_connector_port)
                self._next_source_connector_port += 1
        self._actions.append(("new_pipeline", name, source_config.to_tuple()))
        return self


    def to(self, computation):
        self._actions.append(("to", computation))
        return self

    def to_parallel(self, computation):
        self._actions.append(("to_parallel", computation))
        return self

    def to_stateful(self, computation, state_class, state_name):
        self._actions.append(("to_stateful", computation,
                              StateBuilder(state_name, state_class),
                              state_name))
        return self

    def to_state_partition(self, computation, state_class, state_name,
                           partition_function, partition_keys = []):
        self._actions.append(("to_state_partition", computation,
                              StateBuilder(state_name, state_class),
                              state_name, partition_function, partition_keys))
        return self

    def to_sink(self, sink_config):
        if isinstance(sink_config, wallaroo.experimental.SinkConnectorConfig):
                self._connectors[sink_config._name] = sink_config
                if sink_config._is_unassigned():
                    sink_config._assign('127.0.0.1', self._next_sink_connector_port)
                    self._next_sink_connector_port += 1
        self._actions.append(("to_sink", sink_config.to_tuple()))
        return self

    def to_sinks(self, sink_configs):
        sinks = []
        for sc in sink_configs:
            if isinstance(sc, wallaroo.experimental.SinkConnectorConfig):
                self._connectors[sc._name] = sc
                if sc._is_unassigned():
                    sc._assign('127.0.0.1', self._next_sink_connector_port)
                    self._next_sink_connector_port += 1
            sinks.append(sc.to_tuple())
        self._actions.append(("to_sinks", sinks))
        return self

    def done(self):
        self._actions.append(("done",))
        return self

    def build(self):
        if self._connectors:
            self._actions.append(("connector_definitions", self._connectors))
        self._validate_actions()
        return self._actions

    def _validate_actions(self):
        self._steps = {}
        self._pipelines = {}
        self._states = {}
        last_action = None
        has_sink = False
        # Ensure that we don't add steps unless we are in an unclosed pipeline
        expect_steps = False

        for action in self._actions:
            if action[0][0:2] == "to" and not expect_steps:
                if last_action == "to_sink":
                    raise WallarooParameterError(
                        "Unable to add a computation step after a sink. "
                        "Please declare a new pipeline first.")
                else:
                    raise WallarooParameterError(
                        "Please declare a new pipeline before adding "
                        "computation steps.")

            if action[0] == "new_pipeline":
                self._validate_unique_pipeline_name(action[1], action[2])
                expect_steps = True
            elif action[0] == "to_state_partition":
                self._validate_state(action[2], action[3], action[5])
                self._validate_unique_partition_labels(action[5])
                self._validate_partition_function(action[4])
            elif action[0] == "to_stateful":
                self._validate_state(action[2], action[3])
            elif action[0] == "to_sink":
                has_sink = True
                expect_steps = False

            last_action = action[0]

        # After checking all of our actions, we should have seen at least one
        # pipeline terminated with a sink.
        if not has_sink:
            raise WallarooParameterError(
                "At least one pipeline must define a sink")

    def _validate_unique_pipeline_name(self, pipeline, source_config):
        if pipeline in self._pipelines:
            raise WallarooParameterError((
                "A computation named {0} is defined more than once. "
                "Please use unique names for your steps."
                ).format(repr(computation.name)))
        else:
            self._pipelines[pipeline] = source_config

    def _validate_state(self, ctor, name, partitions = None):
        if name in self._states:
            (other_ctor, other_partitions) = self._states[name]
            if other_ctor.state_cls != ctor.state_cls:
                raise WallarooParameterError((
                    "A state with the name {0} has already been defined with "
                    "an different type {1}, instead of {2}."
                    ).format(repr(name), other_ctor.state_cls, ctor.state_cls))
            if other_partitions != partitions:
                raise WallarooParameterError((
                    "A state with the name {0} has already been defined with "
                    "an different paritioning scheme {1}, instead of {2}."
                    ).format(repr(name), repr(other_partitions), repr(partitions)))
        else:
            self._states[name] = (ctor, partitions)

    def _validate_unique_partition_labels(self, partitions):
        if type(partitions) != list:
            raise WallarooParameterError(
                "Partitions lists should be of type list. Got a {0} instead."
                .format(type(partitions)))
        if len(set(partitions)) != len(partitions):
            raise WallarooParameterError(
                "Partition labels should be uniquely identified via equality "
                "and support hashing. You might have duplicates or objects "
                "which can't be used as keys in a dict.")

    def _validate_partition_function(self, partition_function):
        if not getattr(partition_function, "partition", None):
            raise WallarooParameterError(
                "Partition function is missing partition method. "
                "Did you forget to use the @wallaroo.partition_function "
                "decorator?")


def _validate_arity_compatability(obj, arity):
    """
    To assist in proper API use, it's convenient to fail fast with erros as
    soon as possible. We use this function to check things we decorate for
    compatibility with our desired number of arguments.
    """
    if not callable(obj):
        raise WallarooParameterError(
            "Expected a callable object but got a {0}".format(obj))
    spec = inspect.getargspec(obj)
    upper_bound = len(spec.args)
    lower_bound = upper_bound - (len(spec.defaults) if spec.defaults else 0)
    if arity > upper_bound or arity < lower_bound:
        raise WallarooParameterError((
            "Incompatible function arity, your function must allow {0} "
            "arguments."
            ).format(arity))


def attach_to_module(cls, cls_name, func):
    # Do some scope mangling to create a uniquely named class based on
    # the decorated function's name and place it in the wallaroo module's
    # namespace so that pickle can find it.

    name = cls_name + '__' + func.__name__

    # Python2: use __name__
    if sys.version_info.major == 2:
        cls.__name__ = name
    # Python3: use __qualname__
    else:
        cls.__qualname__ = name

    globals()[name] = cls
    return globals()[name]



def _wallaroo_wrap(name, func, base_cls, **kwargs):
    # Case 1: Computations
    if issubclass(base_cls, Computation):
        # Create the appropriate computation signature
        if base_cls._is_state:
            def comp(self, data, state):
                return func(data, state)
        else:
            def comp(self, data):
                return func(data)

        # Create a custom class type for the computation
        class C(base_cls):
            __doc__ = func.__doc__
            __module__ = __module__
            def name(self):
                return name

        # Attach the computation to the class
        # TODO: maybe move this to machida, using PyObject_IsInstance
        # instead of PyObject_HasAttrString
        if base_cls._is_multi:
            C.compute_multi = comp
        else:
            C.compute = comp

    # Case 2: Partition
    elif base_cls is Partition:
        class C(base_cls):
            def partition(self, data):
                return func(data)

    # Case 3: Encoder
    elif base_cls is Encoder:
        class C(base_cls):
            def encode(self, data):
                return func(data)

    # Case 4: Decoder
    elif base_cls is Decoder:
        header_length = kwargs['header_length']
        length_fmt = kwargs['length_fmt']
        class C(base_cls):
            def header_length(self):
                return header_length
            def payload_length(self, bs):
                return struct.unpack(length_fmt, bs)[0]
            def decode(self, bs):
                return func(bs)

    # Attach the new class to the module's global namespace and return it
    return attach_to_module(C, base_cls.__name__, func)


class BaseWrapped(object):
    def __call__(self, *args):
        return self


class Computation(BaseWrapped):
    _is_multi = False
    _is_state = False


class ComputationMulti(Computation):
    _is_multi = True


class StateComputation(Computation):
    _is_state = True


class StateComputationMulti(StateComputation):
    _is_multi = True


class Partition(BaseWrapped):
    pass


class Decoder(BaseWrapped):
    pass


class Encoder(BaseWrapped):
    pass


def computation(name):
    def wrapped(func):
        _validate_arity_compatability(func, 1)
        C = _wallaroo_wrap(name, func, Computation)
        return C()
    return wrapped


def state_computation(name):
    def wrapped(func):
        _validate_arity_compatability(func, 2)
        C = _wallaroo_wrap(name, func, StateComputation)
        return C()
    return wrapped


def computation_multi(name):
    def wrapped(func):
        _validate_arity_compatability(func, 1)
        C = _wallaroo_wrap(name, func, ComputationMulti)
        return C()
    return wrapped


def state_computation_multi(name):
    def wrapped(func):
        _validate_arity_compatability(func, 2)
        C = _wallaroo_wrap(name, func, StateComputationMulti)
        return C()
    return wrapped


class StateBuilder(object):
    def __init__(self, name, state_cls):
        self.name = name
        self.state_cls = state_cls

    def ____wallaroo_build____(self):
        return self.state_cls()

    def name(self):
        return self.name


def partition(func):
    _validate_arity_compatability(func, 1)
    C = _wallaroo_wrap(func.__name__, func, Partition)
    return C()


def decoder(header_length, length_fmt):
    def wrapped(func):
        _validate_arity_compatability(func, 1)
        C = _wallaroo_wrap(func.__name__, func, Decoder,
                           header_length = header_length,
                           length_fmt = length_fmt)
        return C()
    return wrapped


def encoder(func):
    _validate_arity_compatability(func, 1)
    C = _wallaroo_wrap(func.__name__, func, Encoder)
    return C()


class TCPSourceConfig(object):
    def __init__(self, host, port, decoder):
        self._host = host
        self._port = port
        self._decoder = decoder

    def to_tuple(self):
        return ("tcp", self._host, self._port, self._decoder)


class TCPSinkConfig(object):
    def __init__(self, host, port, encoder):
        self._host = host
        self._port = port
        self._encoder = encoder

    def to_tuple(self):
        return ("tcp", self._host, self._port, self._encoder)


class CustomKafkaSourceCLIParser(object):
    def __init__(self, args, decoder):
        (in_topic, in_brokers,
        in_log_level) = kafka_parse_source_options(args)

        self.topic = in_topic
        self.brokers = in_brokers
        self.log_level = in_log_level
        self.decoder = decoder

    def to_tuple(self):
        return ("kafka", self.topic, self.brokers, self.log_level, self.decoder)

class CustomKafkaSinkCLIParser(object):
    def __init__(self, args, encoder):
        (out_topic, out_brokers, out_log_level, out_max_produce_buffer_ms,
         out_max_message_size) = kafka_parse_sink_options(args)

        self.topic = out_topic
        self.brokers = out_brokers
        self.log_level = out_log_level
        self.max_produce_buffer_ms = out_max_produce_buffer_ms
        self.max_message_size = out_max_message_size
        self.encoder = encoder

    def to_tuple(self):
        return ("kafka", self.topic, self.brokers, self.log_level,
                self.max_produce_buffer_ms, self.max_message_size, self.encoder)

class DefaultKafkaSourceCLIParser(object):
    def __init__(self, decoder, name="kafka_source"):
        self.decoder = decoder
        self.name = name

    def to_tuple(self):
        return ("kafka-internal", self.name, self.decoder)

class DefaultKafkaSinkCLIParser(object):
    def __init__(self, encoder, name="kafka_sink"):
        self.encoder = encoder
        self.name = name

    def to_tuple(self):
        return ("kafka-internal", self.name, self.encoder)

def tcp_parse_input_addrs(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('-i', '--in', dest="input_addrs")
    input_addrs = parser.parse_known_args(args)[0].input_addrs
    # split H1:P1,H2:P2... into [(H1, P1), (H2, P2), ...]
    return [tuple(x.split(':')) for x in input_addrs.split(',')]


def tcp_parse_output_addrs(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('-o', '--out', dest="output_addrs")
    output_addrs = parser.parse_known_args(args)[0].output_addrs
    # split H1:P1,H2:P2... into [(H1, P1), (H2, P2), ...]
    return [tuple(x.split(':')) for x in output_addrs.split(',')]


def kafka_parse_source_options(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('--kafka_source_topic', dest="topic",
                        default="")
    parser.add_argument('--kafka_source_brokers', dest="brokers",
                        default="")
    parser.add_argument('--kafka_source_log_level', dest="log_level",
                        default="Warn",
                        choices=["Fine", "Info", "Warn", "Error"])

    known_args = parser.parse_known_args(args)[0]

    brokers = [_kafka_parse_broker(b) for b in known_args.brokers.split(",")]

    return (known_args.topic, brokers, known_args.log_level)


def kafka_parse_sink_options(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('--kafka_sink_topic', dest="topic",
                        default="")
    parser.add_argument('--kafka_sink_brokers', dest="brokers",
                        default="")
    parser.add_argument('--kafka_sink_log_level', dest="log_level",
                        default="Warn",
                        choices=["Fine", "Info", "Warn", "Error"])
    parser.add_argument('--kafka_sink_max_produce_buffer_ms',
                        dest="max_produce_buffer_ms",
                        type=int,
                        default=0)
    parser.add_argument('--kafka_sink_max_message_size',
                        dest="max_message_size",
                        type=int,
                        default=100000)

    known_args = parser.parse_known_args(args)[0]

    brokers = [_kafka_parse_broker(b) for b in known_args.brokers.split(",")]

    return (known_args.topic, brokers, known_args.log_level,
            known_args.max_produce_buffer_ms, known_args.max_message_size)

def _kafka_parse_broker(broker):
    """
    `broker` is a string of `host[:port]`, return a tuple of `(host, port)`
    """
    host_and_port = broker.split(":")

    host = host_and_port[0]
    port = "9092"

    if len(host_and_port) == 2:
        port = host_and_port[1]

    return (host, port)
