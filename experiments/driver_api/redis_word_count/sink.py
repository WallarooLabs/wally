from __future__ import print_function
import time
import socket
import struct
import threading

from redis import Redis
from wallaroo.experimental import SinkDriver, Session

redis = Redis()

WORKER_COUNT = 16

# TODO: parse this and write it to redis
def print_output(conn):
    message = conn.read()
    print(message)

driver = SinkDriver('127.0.0.1', 7002, backlog = WORKER_COUNT)
while True:
    conn = driver.accept()
    thread = threading.Thread(target = print_output, args = (conn,))
    thread.start()
