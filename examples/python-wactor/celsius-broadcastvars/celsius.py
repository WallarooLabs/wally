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


import struct
import wactor


def create_actor_system(args):
    actor_system = wactor.ActorSystem("Celsius converter with broadcast vars")
    actor_system.add_source(Decoder())
    actor_system.add_actor(Multiply())
    actor_system.add_actor(Add())
    actor_system.add_sink(Encoder())
    actor_system.create_broadcast_variable("add_constant", 32)
    actor_system.create_broadcast_variable("multiply_factor", 1.8)
    return actor_system


class Decoder(wactor.Source):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">L", bs)[0]

    def decode(self, bs):
        return struct.unpack('>f', bs)[0]


class Multiply(wactor.WActor):
    def setup(self):
        self.register_as_role("multiply")
        self.register_as_role("ingress")
        self.update_broadcast_variable("add_constant", 32)
        self.subscribe_to_broadcast_variable("multiply_factor")

    def receive(self, sender_id, msg):
        #Multiply should never receive messages
        print msg
        #raise "receive on Multiply"

    def process(self, data):
        factor = self.read_broadcast_variable("multiply_factor")
        if type(data) is float:
            self.send_to_role("add", data * factor)
        else:
            print "wrong data type received: {0}".format(type(msg))


class Add(wactor.WActor):
    def setup(self):
        self.register_as_role("add")
        self.update_broadcast_variable("multiply_factor", 1.8)
        self.subscribe_to_broadcast_variable("add_constant")

    def receive(self, sender_id, msg):
        const = self.read_broadcast_variable("add_constant")
        if type(msg) is float:
            self.send_to_sink(0, msg + const)
            self.send_to(sender_id, msg)
        else:
            print "wrong message type received: {0}".format(type(msg))

    def process(self, data):
        #Add should never receive data
        raise "process on Add"


class Encoder(object):
    def encode(self, data):
        # data is a float
        return struct.pack('>Lf', 4, data)
