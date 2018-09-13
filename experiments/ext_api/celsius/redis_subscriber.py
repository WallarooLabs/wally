from __future__ import print_function
import sys

from redis import Redis
from celsius_stream_def import CelsiusStream, parse_celsius_stream_addr

redis = Redis()
celsius_stream_addr = parse_celsius_stream_addr(sys.argv)
extension = TextStream(*celsius_stream_addr).extension()

print("Subscribing to 'celsius'")
pubsub = redis.pubsub()
pubsub.subscribe('celsius-in')
for message in pubsub.listen():
    if message['type'] == 'message':
        extension.write(message['data'])
