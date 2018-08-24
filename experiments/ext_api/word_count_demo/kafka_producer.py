from __future__ import print_function
import threading
import sys

from wallaroo.contrib.kafka import parse_kafka_params
from kafka import KafkaProducer
from word_counts import CountStream, parse_count_stream_addr


count_stream_addr = parse_count_stream_addr(sys.argv)
extension = CountStream(*count_stream_addr).extension()
params = parse_kafka_params(sys.argv)
producer = KafkaProducer(bootstrap_servers=params.bootstrap_broker)

while True:
    word, count = extension.read()
    producer.send(params.topics[0], key=word, value=count)
