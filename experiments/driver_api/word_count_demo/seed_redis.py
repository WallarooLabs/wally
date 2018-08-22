from __future__ import print_function
import os
import time
import sys

from redis import Redis

redis = Redis()

project = os.path.dirname(__file__)
bill_path = os.path.join(project, "data/bill_of_rights.txt")
with open(bill_path, 'r') as file:
    bill = file.read()

print("Publishing to redis as 'text'")
while True:
    redis.publish('text', bill)
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
