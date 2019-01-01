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
from collections import Counter
import datetime
import pickle
import struct
import inspect
import sys


# Stand-in for the full command line args tuple to be created during startup.
_ARGS = tuple()


class Unbuffered(object):
    def __init__(self, stream):
        self.stream = stream

    def write(self, data):
        self.stream.write(data)
        self.stream.flush()

    def writelines(self, datas):
        self.stream.writelines(datas)
        self.stream.flush()

    def __getattr__(self, attr):
        return getattr(self.stream, attr)


# If python is running with PIPE stdout/stderr, replace them with
# ones that always flush
if not sys.stdout.isatty():
    sys.stdout = Unbuffered(sys.stdout)
if not sys.stderr.isatty():
    sys.stderr = Unbuffered(sys.stderr)


def serialize(o):
    s = pickle.dumps(o)
    return s


def deserialize(bs):
    return pickle.loads(bs)


class WallarooParameterError(Exception):
    pass


def source(name, source_config):
    return Pipeline.from_source(name, source_config)


def build_application(app_name, pipeline):
    if not pipeline._is_closed():
        print("\nAPI_Error: An application must end with to_sink/s.")
        raise WallarooParameterError()
    return pipeline.__to_tuple__(app_name)


def range_windows(wrange):
    return RangeWindowsBuilder(wrange)


def count_windows(wrange):
    return CountWindowsBuilder(wrange)


class Pipeline(object):
    def __init__(self, pipeline_tree):
        self._pipeline_tree = pipeline_tree

    @classmethod
    def from_source(class_object, name, source_config):
        pipeline_tree = _PipelineTree(("source", name,
                                      source_config.to_tuple()))
        return Pipeline(pipeline_tree)

    def __to_tuple__(self, app_name):
        return self._pipeline_tree.to_tuple(app_name)

    def _is_closed(self):
        return self._pipeline_tree.is_closed

    def to(self, computation):
        return self.clone()._to(computation)

    def _to(self, computation):
        if isinstance(computation, StateComputation):
            self._pipeline_tree.add_stage(("to_state", computation))
        elif isinstance(computation, RangeWindows):
            self._pipeline_tree.add_stage(("to_range_windows",
                                           computation.range,
                                           computation.slide,
                                           computation.delay,
                                           computation.aggregation))
        elif isinstance(computation, CountWindows):
            self._pipeline_tree.add_stage(("to_count_windows",
                                           computation.count,
                                           computation.aggregation))
        else:
            self._pipeline_tree.add_stage(("to", computation))
        return self

    def to_sink(self, sink_config):
        return self.clone()._to_sink(sink_config)

    def _to_sink(self, sink_config):
        self._pipeline_tree.add_stage(("to_sink", sink_config.to_tuple()))
        return self

    def to_sinks(self, sink_configs):
        return self.clone()._to_sinks(sink_configs)

    def _to_sinks(self, sink_configs):
        sinks = []
        for sc in sink_configs:
            sinks.append(sc.to_tuple())
        self._pipeline_tree.add_stage(("to_sinks", sinks))
        return self

    def key_by(self, key_extractor):
        return self.clone()._key_by(key_extractor)

    def _key_by(self, key_extractor):
        self._pipeline_tree.add_stage(("key_by", key_extractor))
        return self

    def collect(self):
        return self.clone()._collect()

    def _collect(self):
        self._pipeline_tree.add_stage(("collect", ""))
        return self

    def merge(self, pipeline):
        return self.clone()._merge(pipeline.clone())

    def _merge(self, pipeline):
        self._pipeline_tree.merge(pipeline._pipeline_tree)
        return self

    def clone(self):
        return Pipeline(self._pipeline_tree.clone())

    def _sources(self):
        return self._pipeline_tree.sources()

    def _sinks(self):
        return self._pipeline_tree.sinks()


def _validate_arity_compatability(name, obj, arity):
    """
    To assist in proper API use, it's convenient to fail fast with errors as
    soon as possible. We use this function to check things we decorate for
    compatibility with our desired number of arguments.
    """
    if not callable(obj):
        print("\nAPI_Error: Expected a callable object but got a {0} for {1}"
              .format(obj, name))
        raise WallarooParameterError()
    spec = inspect.getargspec(obj)
    upper_bound = len(spec.args)
    lower_bound = upper_bound - (len(spec.defaults) if spec.defaults else 0)
    if arity > upper_bound or arity < lower_bound:
        if arity == 1:
            param_term = 'parameter'
        else:
            param_term = 'parameters'
        print("\nAPI_Error: Incompatible function arity, your function {0} must have {1} {2}."
             ).format(name, arity, param_term)
        raise WallarooParameterError()


def _validate_aggregation(agg_cls):
    ## TODO: add arity validation on these methods
    if not hasattr(agg_cls, 'name'):
        print("\nAPI_Error: Aggregation must have method 'name'.")
        raise WallarooParameterError()
    if not hasattr(agg_cls, 'initial_accumulator'):
        print("\nAPI_Error: Aggregation must have method 'initial_accumulator'.")
        raise WallarooParameterError()
    if not hasattr(agg_cls, 'update'):
        print("\nAPI_Error: Aggregation must have method 'update'.")
        raise WallarooParameterError()
    if not hasattr(agg_cls, 'combine'):
        print("\nAPI_Error: Aggregation must have method 'combine'.")
        raise WallarooParameterError()
    if not hasattr(agg_cls, 'output'):
        print("\nAPI_Error: Aggregation must have method 'output'.")
        raise WallarooParameterError()


def attach_to_module(cls, cls_name, func, idx=None):
    # Do some scope mangling to create a uniquely named class based on
    # the decorated function's name and place it in the wallaroo module's
    # namespace so that pickle can find it.

    name = '{cls}{idx}__{func}'.format(
        cls = cls_name,
        idx = '_{}'.format(idx) if idx else '',
        func = func.__name__)

    # Python2: use __name__
    if sys.version_info.major == 2:
        cls.__name__ = name
    # Python3: use __qualname__
    else:
        cls.__qualname__ = name

    globals()[name] = cls
    return globals()[name]


_C = Counter()
def _wallaroo_wrap(name, func, base_cls, **kwargs):
    # Case 1: Computations
    if issubclass(base_cls, Computation):
        # Create the appropriate computation signature

        # Stateful
        if issubclass(base_cls, StateComputation):
            state_class = kwargs.pop('state_class')

            def comp(self, data, state):
                return func(data, state)

            def build_initial_state(self):
                return state_class()

            _is_stateful = True
        # Stateless
        else:
            def comp(self, data):
                return func(data)
            build_initial_state = None
            _is_stateful = False

            build_initial_state = None
            _is_stateful = False

        # Create a custom class type for the computation
        class C(base_cls):
            __doc__ = func.__doc__
            __module__ = __module__
            initial_state = build_initial_state
            is_stateful = _is_stateful

            def name(self):
                return name

        # Attach the computation to the class
        # TODO: maybe move this to machida, using PyObject_IsInstance
        # instead of PyObject_HasAttrString
        if issubclass(base_cls, ComputationMulti):
            C.compute_multi = comp
        else:
            C.compute = comp

    # Case 2: Partition
    elif issubclass(base_cls, KeyExtractor):
        class C(base_cls):
            def extract_key(self, data):
                res = func(data)
                if isinstance(res, int):
                    return chr(res)
                return res

    # Case 3: Encoder
    elif issubclass(base_cls, Encoder):
        # ConnectorEncoder
        if issubclass(base_cls, ConnectorEncoder):
            # Assign `func` to `_encode` attribute. The rest is done in
            # the ConnectorEncoder class definition
            class C(base_cls):
                def encode(self, data, event_time=0, key=None):
                    encoded_data = func(data)
                    return self._encode(encoded_data, event_time, key)

        # OctetEncoder
        elif issubclass(base_cls, OctetEncoder):
            class C(base_cls):
                def encode(self, data):
                    return func(data)

    # Case 4: Decoder
    elif issubclass(base_cls, Decoder):
        # OctetDecoder
        if issubclass(base_cls, OctetDecoder):
            header_length = kwargs['header_length']
            length_fmt = kwargs['length_fmt']

            class C(base_cls):
                def header_length(self):
                    return header_length

                def payload_length(self, bs):
                    return struct.unpack(length_fmt, bs)[0]

                def decode(self, bs):
                    return func(bs)

        # ConnectorDecoder
        elif issubclass(base_cls, ConnectorDecoder):
            class C(base_cls):
                def header_length(self):
                    # struct.calcsize('<I')
                    return 4

                def payload_length(self, bs):
                    return struct.unpack(">I", bs)[0]

                def decode(self, bs):
                    return func(bs)

                def decoder(self):
                    return func

    # Attach the new class to the module's global namespace and return it
    global _C
    _C[base_cls] += 1
    c = attach_to_module(C, base_cls.__name__, func, _C[base_cls])
    return c


class BaseWrapped(object):
    def __call__(self, *args):
        return self


class Computation(BaseWrapped):
    _is_multi = False
    pass


class ComputationMulti(Computation):
    _is_multi = True
    pass


class StateComputation(Computation):
    pass


class StateComputationMulti(StateComputation, ComputationMulti):
    pass


class Aggregation(BaseWrapped):
    def name(self):
        return self.__class__.__name__


class KeyExtractor(BaseWrapped):
    pass


class Encoder(BaseWrapped):
    pass


class Decoder(BaseWrapped):
    pass


class OctetDecoder(Decoder):
    pass


class OctetEncoder(Encoder):
    pass


class ConnectorDecoder(Decoder):
    pass


# datetime.datetime.timestamp() is only available in python 3.3+
if sys.version_info.major >= 3 and sys.version_info.minor >= 3:
    def dt_to_timestamp(dt):
        return dt.timestamp()
else:
    def dt_to_timestamp(dt):
        # Use the native timezone provided in the event_time object
        # If none is provided, it defaults to system timezone
        return ((dt.astimezone() -
                 datetime.datetime(1970,1,1, tzinfo=datetime.timezone.utc)) /
                datetime.timedelta(seconds=1), time.time())


class ConnectorEncoder(Encoder):
    def _encode(self, encoded_data, event_time=0, key=None):
        if isinstance(event_time, datetime.datetime):
            # We'll assume naive datetime values should be treated as
            # UTC. Python's brain-dead datetime package is mostly
            # useless for fixing this without a mountain of caveats
            # like improper DST handling. We'll assume the user can
            # import a library that handles this better than Python
            # does itself.
            #
            # Convert to an integer number of ms from the floating
            # point seconds that Python uses.
            # timestamp() is only available in python3.3+

            event_time = int(dt_to_timestamp(event_time) * 1000)
        encoded_key = key.encode() if key else ''.encode()
        return struct.pack(
            '>IqI{}s{}s'.format(len(encoded_key), len(encoded_data)),
            # 1st I = message length hdr, not included in total frame size
            8 + 4 + len(encoded_key) + len(encoded_data), # total frame size
            event_time, # 64bit event_time
            len(encoded_key),
            encoded_key,
            encoded_data) # final payload, variable size as formatted above


def computation(name):
    def wrapped(func):
        _validate_arity_compatability(name, func, 1)
        C = _wallaroo_wrap(name, func, Computation)
        return C()
    return wrapped


def state_computation(name, state):
    def wrapped(func):
        _validate_arity_compatability(name, func, 2)
        C = _wallaroo_wrap(name, func, StateComputation, state_class=state)
        return C()
    return wrapped


def computation_multi(name):
    def wrapped(func):
        _validate_arity_compatability(name, func, 1)
        C = _wallaroo_wrap(name, func, ComputationMulti)
        return C()
    return wrapped


def state_computation_multi(name, state):
    def wrapped(func):
        _validate_arity_compatability(name, func, 2)
        C = _wallaroo_wrap(name, func, StateComputationMulti,
                           state_class=state)
        return C()
    return wrapped


def key_extractor(func):
    _validate_arity_compatability(func.__name__, func, 1)
    C = _wallaroo_wrap(func.__name__, func, KeyExtractor)
    return C()


def decoder(header_length, length_fmt):
    def wrapped(func):
        _validate_arity_compatability(func.__name__, func, 1)
        C = _wallaroo_wrap(func.__name__, func, OctetDecoder,
                           header_length=header_length,
                           length_fmt=length_fmt)
        return C()
    return wrapped


def encoder(func):
    _validate_arity_compatability(func.__name__, func, 1)
    C = _wallaroo_wrap(func.__name__, func, OctetEncoder)
    return C()


class TCPSourceConfig(object):
    def __init__(self, name, host, port, decoder, valid=True, parallelism=10):
        self._host = host
        self._port = port
        self._name = name
        self._decoder = decoder
        self._valid = valid
        self._parallelism = parallelism

    def to_tuple(self):
        return ("tcp", self._name, self._host, self._port, self._decoder,
                self._valid, self._parallelism)


class GenSourceConfig(object):
    def __init__(self, name, gen_instance):
        self._gen = gen_instance
        self._name = name

    def to_tuple(self):
        return ("gen", self._name, self._gen)


class TCPSinkConfig(object):
    def __init__(self, host, port, encoder):
        self._host = host
        self._port = port
        self._encoder = encoder
        self._name = "" # dummy var

    def to_tuple(self):
        return ("tcp", self._name, self._host, self._port, self._encoder)


class CustomKafkaSourceCLIParser(object):
    def __init__(self, args, decoder):
        (in_topic, in_brokers, in_log_level, in_name) = kafka_parse_source_options(args)

        self.topic = in_topic
        self.brokers = in_brokers
        self.log_level = in_log_level
        self._name = in_name
        self.decoder = decoder

    def to_tuple(self):
        return ("kafka", self._name, self.topic, self.brokers, self.log_level,
                self.decoder)


class CustomKafkaSinkCLIParser(object):
    def __init__(self, args, encoder):
        (out_name, out_topic, out_brokers, out_log_level,
         out_max_produce_buffer_ms,
         out_max_message_size) = kafka_parse_sink_options(args)

        self.topic = out_topic
        self.brokers = out_brokers
        self.log_level = out_log_level
        self.max_produce_buffer_ms = out_max_produce_buffer_ms
        self.max_message_size = out_max_message_size
        self.encoder = encoder
        self._name = out_name

    def to_tuple(self):
        return ("kafka", self._name, self.topic, self.brokers, self.log_level,
                self.max_produce_buffer_ms, self.max_message_size,
                self.encoder)


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
    # split N1@H1:P1,N2@H2:P2... into [(N1, H1, P1), (N2, H2, P2), ...]
    return [tuple(x.replace('@',':').split(':'))
            for x in input_addrs.split(',')]


def tcp_parse_output_addrs(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('-o', '--out', dest="output_addrs")
    output_addrs = parser.parse_known_args(args)[0].output_addrs
    # split H1:P1,H2:P2... into [(H1, P1), (H2, P2), ...]
    return [tuple(x.split(':')) for x in output_addrs.split(',')]


def kafka_parse_source_options(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    parser.add_argument('--kafka_source_name', dest="name")
    parser.add_argument('--kafka_source_topic', dest="topic",
                        default="")
    parser.add_argument('--kafka_source_brokers', dest="brokers",
                        default="")
    parser.add_argument('--kafka_source_log_level', dest="log_level",
                        default="Warn",
                        choices=["Fine", "Info", "Warn", "Error"])

    known_args = parser.parse_known_args(args)[0]

    brokers = [_kafka_parse_broker(b) for b in known_args.brokers.split(",")]

    return (known_args.name, known_args.topic, brokers, known_args.log_level)


def kafka_parse_sink_options(args):
    parser = argparse.ArgumentParser(prog="wallaroo")
    # TODO: enable this when named sinks are implemented
    #parser.add_argument('--kafka_sink_name', dest="name")
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
    name = "" # Replace with real value when this is implemented for sinks

    return (name, known_args.topic, brokers, known_args.log_level,
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


# Each node is a list of stages. Each of these lists will either begin with a
# "source" stage (if it is a leaf of the tree) or a "merge" stage (if it is not
# a leaf).
class _PipelineTree(object):
    def __init__(self, source_stage):
        self.root_idx = 0
        self.vs = [[source_stage]]
        self.es = [[]]
        self.is_closed = False

    def is_empty(self):
        return len(self.vs == 0)

    def add_stage(self, stage):
        if self.is_closed:
            print("\nAPI_Error: You can't add stages after to_sink/s.")
            raise WallarooParameterError()
        self.vs[self.root_idx].append(stage)
        if (stage[0] == 'to_sink') or (stage[0] == 'to_sinks'):
            self.is_closed = True
        return self

    def merge(self, p_graph):
        idx = len(self.vs)
        self.vs.append([])
        self.es.append([self.root_idx])
        self.root_idx = idx
        diff = len(self.vs)
        for v in p_graph.vs:
            stages_clone = []
            for stage in v:
                stages_clone.append(stage)
            self.vs.append(stages_clone)
        for es in p_graph.es:
            new_es = []
            for e_idx in es:
                new_es.append(e_idx + diff)
            self.es.append(new_es)
        self.es[self.root_idx].append(p_graph.root_idx + diff)
        return self

    def to_tuple(self, app_name):
        p_tree = self.clone()
        return (app_name, p_tree.root_idx, p_tree.vs, p_tree.es)

    def clone(self):
        new_vs = []
        new_es = []
        for v in self.vs:
            new_stages = []
            for stage in v:
                new_stages.append(stage)
            new_vs.append(new_stages)
        for es in self.es:
            new_outs = []
            for out in es:
                new_outs.append(out)
            new_es.append(new_outs)
        pt = _PipelineTree(None)
        pt.root_idx = self.root_idx
        pt.vs = new_vs
        pt.es = new_es
        pt.is_closed = self.is_closed
        return pt

    def sources(self):
        sources = []
        for stage in self.vs:
            for step in stage:
                if step[0] == "source":
                    sources.append(step)
        return sources

    def sinks(self):
        sinks = []
        for stage in self.vs:
            for step in stage:
                if step[0] == "to_sink":
                    sinks.append(step)
        return sinks


class RangeWindowsBuilder(object):
    def __init__(self, wrange):
        self.range = wrange
        self.slide = None
        self.delay = None
        self.default_slide = self.range
        self.default_delay = 0

    def with_slide(self, slide):
        if self.slide is None:
            self.slide = slide
        else:
            print("API_Error: Only call `with_slide()` once per window specification.")
            raise WallarooParameterError()
        return self

    def with_delay(self, delay):
        if self.delay is None:
            self.delay = delay
        else:
            print("API_Error: Only call `with_delay()` once per window specification.")
            raise WallarooParameterError()
        return self

    def over(self, aggregation_cls):
        if self.slide is None:
            slide = self.range
        else:
            slide = self.slide

        if self.delay is None:
            delay = 0
        else:
            delay = self.delay

        return RangeWindows(self.range, slide, delay, aggregation_cls())



class RangeWindows(object):
    def __init__(self, wrange, slide, delay, agg):
        self.range = wrange
        self.slide = slide
        self.delay = delay
        _validate_aggregation(agg)
        self.aggregation = agg


class CountWindowsBuilder(object):
    def __init__(self, count):
        self.count = count

    def over(self, aggregation_cls):
        return CountWindows(self.count, aggregation_cls())


class CountWindows(object):
    def __init__(self, count, agg):
        self.count = count
        _validate_aggregation(agg)
        self.aggregation = agg


##############
# Time Units
##############
def nanoseconds(x):
    return x


def microseconds(x):
    return nanoseconds(x) * 1000


def milliseconds(x):
    return microseconds(x) * 1000


def seconds(x):
    return milliseconds(x) * 1000


def minutes(x):
    return seconds(x) * 60


def hours(x):
    return minutes(x) * 60
