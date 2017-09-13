# Copyright 2017 The Wallaroo Authors.
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


import wactor
import random

ACTOR_COUNT = 5
ALL_ROLES = ["counter", "accumulator"]


def create_actor_system(args):
    actor_system = wactor.ActorSystem("Toy model CRDT App")
    actor_system.add_simulated_source()
    actor_system.add_actor(A("accumulator"))
    for i in range(ACTOR_COUNT - 1):
        actor_system.add_actor(A("counter"))
    return actor_system


class ActMsg(object):
    pass


class IncrementsMsg(object):
    def __init__(self, count):
        self.count = count


class GossipMsg(object):
    def __init__(self, data):
        self.data = data


class FinishMsg(object):
    pass


class FinishGossipMsg(object):
    pass


class GCounter:

    def __init__(self, counter_id):
        self._id = counter_id
        self.data = {}

    def increment(self):
        if self._id in self.data:
            self.data[self._id] += 1
        else:
            self.data[self._id] = 1

    def merge(self, other):
        for k in self.data.keys() + other.keys():
            if k in other:
                if k in self.data:
                    self.data[k] = max(self.data[k], other[k])
                else:
                    self.data[k] = other[k]

    def value(self):
        return sum(self.data.values())

    def __str__(self):
        return "GCounter({0})".format(self.value())


class A(wactor.WActor):

    def __init__(self, role):
        wactor.WActor.__init__(self)
        self._pending_increments = 0
        self._waiting = 0
        self._round = 0
        self.role = role

    def setup(self):
        self._g_counter = GCounter(counter_id=self.actor_id >> 96)
        for role in ALL_ROLES + ["ingress"]:
            self.register_as_role(role)

    def receive(self, sender_id, msg):
        message_type = type(msg)
        if message_type is ActMsg:
            self.act()
        elif message_type is IncrementsMsg:
            self._pending_increments += msg.count
        elif message_type is GossipMsg:
            self._g_counter.merge(msg.data)
        elif message_type is FinishMsg:
            for _ in range(self._pending_increments):
                self._g_counter.increment()
            self._pending_increments = 0
            if self.role == "counter":
                self.send_to_role("accumulator",
                                  FinishGossipMsg(self._g_counter.data))
        elif message_type is FinishGossipMsg:
            self._g_counter.merge(m.data)
            print "finishing: {0}".format(str(self._g_counter))
        else:
            print "unknown message type received: {0}".format(message_type)

    def process(self, data):
        self.act()
        if self.role == "accumulator":
            print "accumulator act report: {0}".format(str(self._g_counter))

    def act(self):
        if self.role == "accumulator":
            print "round {0}: {1}".format(self._round, str(self._g_counter))
        else:
            while self._pending_increments > 0:
                self._g_counter.increment()
                self._pending_increments -= 1
            self.emit_messages()
        self._round += 1

    def emit_messages(self):
        inc_msg_count = random.randint(1, 4)
        self._waiting += inc_msg_count
        for i in range(0, inc_msg_count):
            msg = IncrementsMsg(random.randint(1, 3))
            self.send_to_role("counter", msg)
        gossip_msg_count = random.randint(1, 4)
        self._waiting += gossip_msg_count
        msg = GossipMsg(self._g_counter.data)
        for i in range(0, gossip_msg_count):
            self.send_to_role("counter", msg)
        self.send_to_role("accumulator", msg)
