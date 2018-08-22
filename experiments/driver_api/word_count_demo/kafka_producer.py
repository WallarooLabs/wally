from __future__ import print_function
import threading
import sys

from wallaroo.contrib.kafka import parse_kafka_params
from kafka import KafkaProducer
from word_counts import CountStream, parse_count_stream_addr


def publish_counts(conn, producer, topic):
    while True:
        # TODO: teardown closed connections properly by moving back to select
        # based socket reader. asyncio in Python 3 would also be a future option.
        word, count = conn.read()
        producer.send(topic, key=word, value=count)

count_stream_addr = parse_count_stream_addr(sys.argv)
driver = CountStream(*count_stream_addr).driver()
params = parse_kafka_params(sys.argv)
producer = KafkaProducer(bootstrap_servers=params.bootstrap_broker)

while True:
    conn = driver.accept()
    thread = threading.Thread(target=publish_counts, args=(conn, producer, params.topics[0]))
    thread.start()
