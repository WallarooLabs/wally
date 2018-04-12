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

import argparse
import struct
import wallaroo

# commented out because the following break pickle serialization
#
#def create_multiply(factor):
#    def custom_multiply(data):
#        return data * factor
#
#    return custom_multiply
#
#def create_add(amount):
#    def custom_add(data):
#        return data * amount
#
#    return custom_add

multiplication_factor = 1.8
add_amount = 32

def application_setup(args, show_help):

    parser = argparse.ArgumentParser(prog='')
    parser.add_argument('--multiply_factor', type=float, default=1.8, help='the multiplication factor to use (default: %(default)s)')
    parser.add_argument('--add_amount', type=int, default=32, help='the amount to add (default: %(default)s)')

    if show_help:
      print "-------------------------------------------------------------------------"
      print "This application takes the following parameters:"
      print "-------------------------------------------------------------------------"
      parser.print_help()

    a, _ = parser.parse_known_args(args)

# commented out because the following break pickle serialization
#
#    custom_multiply = wallaroo.computation(name="custom_multiply")(create_multiply(a.multiply_factor))
#    custom_add = wallaroo.computation(name="custom_add")(create_add(a.add_amount))

    global multiplication_factor
    global add_amount

    multiplication_factor = a.multiply_factor
    add_amount = a.add_amount

    ab = wallaroo.ApplicationBuilder("Celsius to Fahrenheit with Kafka")

    ab.new_pipeline("convert",
                    wallaroo.DefaultKafkaSourceCLIParser(decoder))

# commented out because the following break pickle serialization
#
#    ab.to(custom_multiply)
#    ab.to(custom_add)

    ab.to(multiply)
    ab.to(add)

    ab.to_sink(wallaroo.DefaultKafkaSinkCLIParser(encoder))
    return ab.build()


@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(bs):
    try:
      return float(bs.decode("utf-8"))
    except ValueError,e:
      return 0.0

@wallaroo.computation(name="multiply by factor")
def multiply(data):
    return data * multiplication_factor


@wallaroo.computation(name="add amount")
def add(data):
    return data + add_amount


@wallaroo.encoder
def encoder(data):
    # data is a float
    return ("%.6f" % (data), None, None)
