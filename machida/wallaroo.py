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

    def new_pipeline(self, name, decoder, source_config):
        if inspect.isclass(decoder):
            raise WallarooParameterError("Expecting a Decoder instance. Got a "
                                         "class instead.")
        self._actions.append(("new_pipeline", name, decoder,
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

    def to_sink(self, encoder, sink_config):
        if inspect.isclass(encoder):
            raise WallarooParameterError("Expecting an Encoder instance. Got a"
                                         " class instead.")
        self._actions.append(("to_sink", encoder, sink_config.to_tuple()))
        return self

    def done(self):
        self._actions.append(("done",))
        return self

    def build(self):
        return self._actions


class TCPSourceConfig(object):
    def __init__(self, host, port):
        self._host = host
        self._port = port

    def to_tuple(self):
        return ("tcp", self._host, self._port)


class TCPSinkConfig(object):
    def __init__(self, host, port):
        self._host = host
        self._port = port

    def to_tuple(self):
        return ("tcp", self._host, self._port)


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
