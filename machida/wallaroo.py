class ApplicationBuilder(object):
    def __init__(self, name):
        self._actions = [("name", name)]

    def new_pipeline(self, name, decoder, coalescing=True):
        self._actions.append(("new_pipeline", name, decoder, coalescing))
        return self

    def to(self, computation_class):
        self._actions.append(("to", computation_class))
        return self

    def to_stateful(self, computation, state_builder, state_name):
        self._actions.append(("to_stateful", computation, state_builder,
                              state_name))
        return self

    def to_state_partition_u64(self, computation, state_builder, state_name,
                               partition_function, partition_keys):
        self._actions.append(("to_state_partition_u64", computation,
                              state_builder, state_name, partition_function,
                              partition_keys))
        return self

    def to_state_partition(self, computation, state_builder, state_name,
                           partition_function, partition_keys):
        self._actions.append(("to_state_partition", computation, state_builder,
                              state_name, partition_function, partition_keys))
        return self

    def to_sink(self, encoder):
        self._actions.append(("to_sink", encoder))
        return self

    def done(self):
        self._actions.append(("done",))
        return self

    def build(self):
        return self._actions
