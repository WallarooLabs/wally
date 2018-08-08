from __future__ import print_function
import os
import time
import sys

from kafka import KafkaProducer

project = os.path.dirname(__file__)
bill_path = os.path.join(project, "../data/bill_of_rights.txt")
with open(bill_path, 'r') as file:
    bill = file.read()

producer = KafkaProducer(bootstrap_servers='127.0.0.1:9092')

print("Publishing to kafka topic 'text'")
while True:
    producer.send('text', key=b'bill_of_rights', value=b'some_message_bytes')
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
