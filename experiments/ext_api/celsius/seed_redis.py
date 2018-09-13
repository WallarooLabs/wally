from __future__ import print_function
import os
import time
import sys

from redis import Redis

redis = Redis()

print("Publishing to redis as 'celsius-in'")

i = 0

while True:
    redis.publish('celsius-in', str(i).encode("utf-8"))
    i = i + 1
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
