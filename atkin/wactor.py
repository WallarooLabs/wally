# Copyright 2017 The Wallaroo Authors.
#
# Licensed as a Wallaroo Enterprise file under the Wallaroo Community
# License (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#      https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

import pickle

def serialize(o):
    return pickle.dumps(o)


def deserialize(bs):
    return pickle.loads(bs)


def join_longs(left, right):
    r = left << 64
    r += right
    return r


def split_longs(u128):
    l = u128 >> 64
    r = u128 - (l << 64)
    return (l, r)


class WActor(object):
    def __init__(self):
        self._call_log = []
        #TODO: this is currently not populated with defaults, and anything that
        # happens before actor creation (and subscription) is missed.
        self._broadcast_var_values_cache = {}

    def _clear_call_log(self):
        self._call_log = []

    def _get_call_log(self):
        cl = self._call_log
        self._clear_call_log()
        return cl

    def send_to(self, actor_id, msg):
        self._call_log.append(("send_to", (split_longs(actor_id), msg)))

    def send_to_role(self, role, msg):
        self._call_log.append(("send_to_role", (role, msg)))

    def send_to_sink(self, sink_id, msg):
        self._call_log.append(("send_to_sink", (sink_id, msg)))

    def register_as_role(self, role):
        self._call_log.append(("register_as_role", (role)))

    def receive_wrapper(self, sender_id_left, sender_id_right, msg):
        self.receive(join_longs(sender_id_left, sender_id_right), msg)
        return self._get_call_log()

    def process_wrapper(self, data=None):
        self.process(data)
        return self._get_call_log()

    def setup_wrapper(self, actor_id_left, actor_id_right):
        self.actor_id = join_longs(actor_id_left, actor_id_right)
        self.setup()
        return self._get_call_log()

    def receive_broadcast_variable_update_wrapper(self, key, value):
        self._broadcast_var_values_cache[key] = value
        if "receive_broadcast_variable_update" in dir(self):
            self.receive_broadcast_variable_update(self, key, value)

    def subscribe_to_broadcast_variable(self, key):
        self._call_log.append(("subscribe_to_broadcast_variable", key))

    def read_broadcast_variable(self, key):
        if key in self._broadcast_var_values_cache:
            return self._broadcast_var_values_cache[key]
        else:
            return None

    def update_broadcast_variable(self, key, value):
        self._broadcast_var_values_cache[key] = value
        self._call_log.append(("update_broadcast_variable", (key, value)))


class Source(object):
    def kind(self):
        return "external"


class SimulatedSource(object):
    def kind(self):
        return "simulated"


class ActorSystem(object):
    def __init__(self, name):
        self.name = name
        self.actors = []
        self.sources = []
        self.sinks = []
        self.broadcast_variables = []

    def add_actor(self, actor):
        self.actors.append(actor)

    def add_source(self, source):
        self.sources.append(source)

    def add_sink(self, sink):
        self.sinks.append(sink)

    def add_simulated_source(self):
        self.sources.append(SimulatedSource())

    def create_broadcast_variable(self, key, default_value):
        self.broadcast_variables.append((key, default_value))
