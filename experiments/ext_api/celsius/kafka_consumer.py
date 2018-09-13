from __future__ import print_function
import sys

from wallaroo.contrib.kafka import parse_kafka_params
from kafka import KafkaConsumer
from celsius_strem_def import CelsiusStream, parse_celsius_stream_addr

params = parse_kafka_params(sys.argv)
consumer = KafkaConsumer(','.join(params.topics), bootstrap_servers=params.bootstrap_broker, group_id=params.consumer_group)
celsius_stream_addr = parse_celsius_stream_addr(sys.argv)
extension = CelsiusStream(*celsius_stream_addr).extension()

print("Consuming topic 'celsius-in'")
for message in consumer:
    extension.write(message.value)
