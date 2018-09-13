from __future__ import print_function

import os
import sys
import time

from boto import kinesis

conn = kinesis.connect_to_region(region_name = "us-east-1")

print("Creating Kinesis Stream")
pass

print(conn.list_streams())

print("Sending celsius values to kinesis")

i = 0

while True:
    conn.put_record('celsius-in', str(i).encode("utf-8"), str(i).encode("utf-8"))
    i = i + 1
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
