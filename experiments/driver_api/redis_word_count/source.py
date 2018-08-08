from __future__ import print_function
import time
import socket
import struct

from redis import Redis
from wallaroo.experimental import SourceDriver, Session, StreamDescription

redis = Redis()

driver = SourceDriver()
# TODO: switch this to use the StreamDescription we can share
driver.connect('127.0.0.1', 7010)

print("Subscribing to 'text'")
pubsub = redis.pubsub()
pubsub.subscribe('text')
for message in pubsub.listen():
    if message['type'] == 'message':
        driver.write(message['data'])
