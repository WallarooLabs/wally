from __future__ import print_function
import threading
import sys

from wallaroo.contrib.kafka import parse_kafka_params
from kafka import KafkaProducer
from farenheit_stream_def import FarenheitStream, parse_farenheit_stream_addr


farenheit_stream_addr = parse_farenheit_stream_addr(sys.argv)
extension = FarenheitStream(*farenheit_stream_addr).extension()
params = parse_kafka_params(sys.argv)
producer = KafkaProducer(bootstrap_servers=params.bootstrap_broker)

while True:
    farenheit_value = extension.read()
    producer.send(params.topics[0], value=farenheit_value)
