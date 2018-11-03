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

"""
This is an example of a stateless Python application that takes a floating
point Celsius value from Kafka and sends out a floating point Fahrenheit value
to Kafka.
"""

import struct

import wallaroo


def application_setup(args):
    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit with Kafka")

    ab.new_pipeline("convert",
                    wallaroo.DefaultKafkaSourceCLIParser(decoder))

    ab.to(multiply)
    ab.to(add)

    ab.to_sink(wallaroo.DefaultKafkaSinkCLIParser(encoder))
    return ab.build()


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    try:
      return float(bs.decode("utf-8"))
    except ValueError as e:
      return 0.0

@wallaroo.computation(name="multiply by 1.8")
def multiply(data):
    return data * 1.8


@wallaroo.computation(name="add 32")
def add(data):
    return data + 32


@wallaroo.encoder
def encoder(data):
    # data is a float
    return ("%.6f" % (data), None, None)
