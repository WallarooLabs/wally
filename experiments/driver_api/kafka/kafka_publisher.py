from __future__ import print_function
import threading

from wallaroo.experimental import SinkDriver
from kafka import KafkaProducer

import counts

MAX_LOCAL_WORKER_COUNT = 16

def publish_counts(conn, producer):
    while True:
        # TODO: teardown closed connections properly
        word, count = conn.read()
        producer.send('counts', key=word, value=count)


driver = SinkDriver('127.0.0.1', 7200, counts.count_decoder, backlog=MAX_LOCAL_WORKER_COUNT)
producer = KafkaProducer(bootstrap_servers='127.0.0.1:9092')
while True:
    conn = driver.accept()
    thread = threading.Thread(target=publish_counts, args=(conn, producer))
    thread.start()
