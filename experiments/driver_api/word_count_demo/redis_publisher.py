from __future__ import print_function
import sys
import threading

from redis import Redis
from word_counts import CountStream, parse_count_stream_addr


def publish_counts(conn, redis):
    redis = Redis()
    while True:
        word, count = conn.read()
        redis.hset('counts', word, count)


count_stream_addr = parse_count_stream_addr(sys.argv)
driver = CountStream(*count_stream_addr).driver()
redis = Redis()

while True:
    conn = driver.accept()
    thread = threading.Thread(target=publish_counts, args=(conn, redis))
    thread.start()
