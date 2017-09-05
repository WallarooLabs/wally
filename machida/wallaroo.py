

import argparse
import inspect
import pickle


def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


class WallarooParameterError(Exception):
    pass


class ApplicationBuilder(object):
    def __init__(self, name):
        self._actions = [("name", name)]

    def new_pipeline(self, name, source_config):
        self._actions.append(("new_pipeline", name,
                              source_config.to_tuple()))
        return self

    def to(self, computation):
        if not inspect.isclass(computation):
            raise WallarooParameterError("Expecting a Computation class. Got "
                                         "an instance instead.")
        self._actions.append(("to", computation))
        return self

    def to_parallel(self, computation):
        if not inspect.isclass(computation):
            raise WallarooParameterError("Expecting a Computation class. Got "
                                         "an instance instead.")
        self._actions.append(("to_parallel", computation))
        return self

    def to_stateful(self, computation, state_builder, state_name):
        if inspect.isclass(computation):
            raise WallarooParameterError("Expecting a Computation Builder "
                                         "instance. Got a class instead.")
        if inspect.isclass(state_builder):
            raise WallarooParameterError("Expecting a State Builder "
                                         "instance. Got a class instead.")
        self._actions.append(("to_stateful", computation, state_builder,
                              state_name))
        return self

    def to_state_partition_u64(self, computation, state_builder, state_name,
                               partition_function, partition_keys):
        if inspect.isclass(computation):
            raise WallarooParameterError("Expecting a Computation Builder "
                                         "instance. Got a class instead.")
        if inspect.isclass(state_builder):
            raise WallarooParameterError("Expecting a State Builder "
                                         "instance. Got a class instead.")
        self._actions.append(("to_state_partition_u64", computation,
                              state_builder, state_name, partition_function,
                              partition_keys))
        return self

    def to_state_partition(self, computation, state_builder, state_name,
                           partition_function, partition_keys):
        if inspect.isclass(computation):
            raise WallarooParameterError("Expecting a Computation Builder "
                                         "instance. Got a class instead.")
        if inspect.isclass(state_builder):
            raise WallarooParameterError("Expecting a State Builder "
                                         "instance. Got a class instead.")
        if not isinstance(partition_keys, list):
            raise WallarooParameterError("Expecting a partition_keys list. "
                                         "Got a {} instead.".format(
                                             type(partition_keys)))
        self._actions.append(("to_state_partition", computation, state_builder,
                              state_name, partition_function, partition_keys))
        return self

    def to_sink(self, sink_config):
        self._actions.append(("to_sink", sink_config.to_tuple()))
        return self

    def done(self):
        self._actions.append(("done",))
        return self

    def build(self):
        return self._actions


class TCPSourceConfig(object):
    def __init__(self, host, port, encoder):
        self._host = host
        self._port = port
        self._encoder = encoder

    def to_tuple(self):
        return ("tcp", self._host, self._port, self._encoder)


class TCPSinkConfig(object):
    def __init__(self, host, port, decoder):
        self._host = host
        self._port = port
        self._decoder = decoder

    def to_tuple(self):
        return ("tcp", self._host, self._port, self._decoder)


class KafkaSourceConfig(object):
    def __init__(self, topic, brokers, log_level, decoder):
        """
        topic: string
        brokers: list of (string, int) tuples with values (HOST, PORT)
        log_level: string of "Fine", "Info", "Warn", or "Error"
        decoder: decoder
        """
        self.topic = topic
        self.brokers = brokers
        self.log_level = log_level
        self.decoder = decoder

    def to_tuple(self):
        return ("kafka", self.topic, self.brokers, self.log_level, self.decoder)


class KafkaSinkConfig(object):
    def __init__(self, topic, brokers, log_level, max_produce_buffer_ms,
                 max_message_size, encoder):
        self.topic = topic
        self.brokers = brokers
        self.log_level = log_level
        self.max_produce_buffer_ms = max_produce_buffer_ms
        self.max_message_size = max_message_size
        self.encoder = encoder

    def to_tuple(self):
        return ("kafka", self.topic, self.brokers, self.log_level,
                self.max_produce_buffer_ms, self.max_message_size, self.encoder)


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
