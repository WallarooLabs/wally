from __future__ import print_function

import sys
import threading

import boto3
from word_counts import CountStream, parse_count_stream_addr

count_stream_addr = parse_count_stream_addr(sys.argv)
extension = CountStream(*count_stream_addr).extension()
producer = boto3.client('kinesis')

while True:
    word, count = extension.read()
    print (str({word: count}))
    producer.put_record(StreamName='word_count', PartitionKey=word, Data=str(count))
