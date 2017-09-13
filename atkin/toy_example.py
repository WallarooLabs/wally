# Copyright 2017 The Wallaroo Authors.
#
# Licensed as a Wallaroo Enterprise file under the Wallaroo Community
# License (the "License"); you may not use this file except in compliance with
# the License. You may obtain a copy of the License at
#
#      https://github.com/wallaroolabs/wallaroo/blob/master/LICENSE

import wactor
import random
import struct

ALL_ROLES = ["one", "two", "three"]
ACTOR_COUNT = 10


def create_actor_system(args):
    actor_system = wactor.ActorSystem("Toy Model")
    actor_system.add_source(MessageSource())
    actor_system.add_actor(A("one"))
    actor_system.add_actor(A("two"))
    actor_system.add_actor(A("three"))
    for i in range(ACTOR_COUNT - 3):
        actor_system.add_actor(A(random.choice(ALL_ROLES)))
    return actor_system


class SetActorProbability(object):
    def __init__(self, prob):
        self.prob = prob


class SetNumberOfMessagesToSend(object):
    def __init__(self, n):
        self.n = n


class ChangeMessageTypesToSend(object):
    def __init__(self, types):
        self.types = types


class MessageSource(wactor.Source):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">L", bs)[0]

    def decode(self, bs):
        return "Act"


class A(wactor.WActor):

    def __init__(self, role):
        wactor.WActor.__init__(self)
        self.role = role
        self.n = 1
        self.prob = 0.5
        self._all_message_types = ["SetActorProbability",
                                   "SetNumberOfMessagesToSend",
                                   "ChangeMessageTypesToSend"]
        self._message_types_to_send = self._all_message_types

    def setup(self):
        self.register_as_role(self.role)
        self.register_as_role("ingress")

    def receive(self, sender_id, msg):
        msg_type = type(msg)
        if msg_type is SetActorProbability:
            self._emission_prob = msg.prob
            print("Setting prob to {0}".format(msg.prob))
        elif msg_type is SetNumberOfMessagesToSend:
            self._n = msg.n
            print("Setting n to {0}".format(msg.n))
        elif msg_type is ChangeMessageTypesToSend:
            self._message_types_to_send = msg.types
            print("Setting types to {0}".format(msg.types))
        else:
            print("Unknown message type {0} received".format(msg_type))

    def process(self, data):
        for i in range(0, self.n):
            if random.random() < self.prob:
                message = self.create_message()
                role = random.choice(ALL_ROLES)
                print("Sending {0} to {1}".format(str(message), role))
                self.send_to_role(role, message)

    def create_message(self):
        msg_type = random.choice(self._message_types_to_send)
        if msg_type == "SetActorProbability":
            return SetActorProbability(random.random())
        elif msg_type == "SetNumberOfMessagesToSend":
            return SetNumberOfMessagesToSend(random.randint(1, 4))
        elif msg_type == "ChangeMessageTypesToSend":
            return ChangeMessageTypesToSend(random.sample(
                            self._all_message_types,
                            random.randint(1, len(self._all_message_types))))
        else:
            print("Unknown msg type {0} found".format(msg_type))
