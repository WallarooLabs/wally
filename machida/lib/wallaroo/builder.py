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

import inspect
from copy import copy

class ApplicationBuilder(object):

    def __init__(self, name):
        self._partitioned = None
        self._actions = [("name", name)]

    def new_pipeline(self, name, source_config):
        # self._arrange_partitions() # sort out prior pipeline partitions first
        # if type(source_config) == list:
        #     self._partitioned = (source_config, self._actions)
        #     self._actions = [("new_pipeline", name, None)]
        # else:
        self._actions.append(("new_pipeline", name,
                              source_config.to_tuple()))
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
        self._actions.append(("to_sink", sink_config.to_tuple()))
        return self

    def to_sinks(self, sink_configs):
        sinks = []
        for sc in sink_configs:
            sinks.append(sc.to_tuple())
        self._actions.append(("to_sinks", sinks))
        return self

    def done(self):
        self._actions.append(("done",))
        return self

    def build(self):
        # self._arrange_partitions()
        self._validate_actions()
        print("built", repr(self._actions))
        return self._actions

    def _arrange_partitions(self):
        if self._partitioned:
            (source, prior_actions) = self._partitioned
            for idx, partition in enumerate(source):
                actions = copy(self._actions)
                actions[0] = copy(actions[0])
                pipeline_name = actions[0][1] + "({})".format(idx)
                actions[0] = ("new_pipeline", pipeline_name, partition)
                prior_actions.extend(actions)
            self._actions = prior_actions
            self._partitioned = None

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
                "A pipeline named {0} is defined more than once. "
                "Please use unique names for your steps."
                ).format(repr(pipeline)))
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


class StateBuilder(object):
    def __init__(self, name, state_cls):
        self._name = name
        self.state_cls = state_cls

    def ____wallaroo_build____(self):
        return self.state_cls()

    def name(self):
        return self._name


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


class WallarooParameterError(Exception):
    pass

