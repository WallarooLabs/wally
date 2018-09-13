from __future__ import print_function

import sys
import threading

from boto import kinesis
from farenheit_stream_def import FarenheitStream, parse_farenheit_stream_addr

farenheit_stream_addr = parse_farenheit_stream_addr(sys.argv)
extension = FarenheitStream(*farenheit_stream_addr).extension()
producer = kinesis.connect_to_region(region_name = "us-east-1")

while True:
    fareheit_value = extension.read()
    producer.put_record('farenheit-out', farenheit_value, farenheit_value)
