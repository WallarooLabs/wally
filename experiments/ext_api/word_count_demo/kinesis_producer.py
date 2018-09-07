from __future__ import print_function

import sys
import threading

from boto import kinesis
from word_counts import CountStream, parse_count_stream_addr

count_stream_addr = parse_count_stream_addr(sys.argv)
extension = CountStream(*count_stream_addr).extension()
producer = kinesis.connect_to_region(region_name = "us-east-1")

while True:
    word, count = extension.read()
    print (str({word: count}))
    producer.put_record('word_count', str(count), word)
