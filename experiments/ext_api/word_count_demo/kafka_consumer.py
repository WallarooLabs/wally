from __future__ import print_function
import sys

from wallaroo.contrib.kafka import parse_kafka_params
from kafka import KafkaConsumer
from text_documents import TextStream, parse_text_stream_addr

params = parse_kafka_params(sys.argv)
consumer = KafkaConsumer(','.join(params.topics), bootstrap_servers=params.bootstrap_broker, group_id=params.consumer_group)
text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()

print("Consuming topic 'text'")
for message in consumer:
    extension.write(message.value, partition=message.partition, sequence=message.offset)
