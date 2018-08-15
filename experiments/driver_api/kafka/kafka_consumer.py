from __future__ import print_function
import time

from wallaroo.experimental import SourceDriver
from kafka import KafkaConsumer
from text_documents import TextStream, text_encoder

consumer = KafkaConsumer('test', bootstrap_servers='127.0.0.1:9092', group_id='experiment')
driver = SourceDriver(text_encoder)
driver.connect('127.0.0.1', 7100)

print("Consuming topic 'text'")
for message in consumer:
    driver.write(message.value, partition=message.partition, sequence=message.sequence)
