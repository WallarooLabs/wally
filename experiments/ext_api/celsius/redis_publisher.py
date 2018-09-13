from __future__ import print_function
import sys
import threading

from redis import Redis
from farenheit_stream_def import FarenheitStream, parse_farenheit_stream_addr


farenheit_stream_addr = parse_farenheit_stream_addr(sys.argv)
extension = FarenheitStream(*count_stream_addr).extension()
redis = Redis()

while True:
    farenheit_value = extension.read()
    redis.hset('farenheit-out', farenheit_value, farenheit_value)
