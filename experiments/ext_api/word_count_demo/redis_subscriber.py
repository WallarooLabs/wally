from __future__ import print_function
import sys

from redis import Redis
from text_documents import TextStream, parse_text_stream_addr

redis = Redis()
text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()

print("Subscribing to 'text'")
pubsub = redis.pubsub()
pubsub.subscribe('text')
for message in pubsub.listen():
    if message['type'] == 'message':
        extension.write(message['data'])
