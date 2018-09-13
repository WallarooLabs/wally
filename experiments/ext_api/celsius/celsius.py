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
point Celsius value as ascii as input from an external source and sends out
a floating point Fahrenheit value as an ascii string to an external sink.
"""

import struct

import wallaroo
import wallaroo.experimental

import celsius_stream_def
import farenheit_stream_def


def application_setup(args):
    celsius_addr = celsius_stream_def.parse_celsius_stream_addr(args)
    celsius_stream = celsius_stream_def.CelsiusStream(*celsius_addr)
    farenheit_addr = farenheit_stream_def.parse_farenheit_stream_addr(args)
    farenheit_stream = farenheit_stream_def.FarenheitStream(*farenheit_addr)

    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit with External Source/Sink")

    ab.new_pipeline("convert", celsius_stream.source())

    ab.to(to_float_conv)
    ab.to(multiply)
    ab.to(add)

    ab.to_sink(farenheit_stream.sink())
    return ab.build()


@wallaroo.computation(name="convert to float")
def to_float_conv(data):
    try:
      return float(data)
    except ValueError,e:
      return 0.0


@wallaroo.computation(name="multiply by 1.8")
def multiply(data):
    return data * 1.8


@wallaroo.computation(name="add 32")
def add(data):
    return data + 32
