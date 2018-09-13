from __future__ import print_function
import os
import time
import sys

from kafka import KafkaProducer

producer = KafkaProducer(bootstrap_servers='127.0.0.1:9092')

print("Publishing to kafka topic 'celsius-in'")

i = 0

while True:
    producer.send('celsius-in', value=str(i).encode("utf-8"))
    i = i + 1
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
