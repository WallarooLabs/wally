from __future__ import print_function

import os
import sys
import time

from boto import kinesis

conn = kinesis.connect_to_region(region_name = "us-east-1")

project = os.path.dirname(__file__)
bill_path = os.path.join(project, "data/bill_of_rights.txt")
with open(bill_path, 'r') as file:
    bill = file.read()


print("Creating Kinesis Stream")
pass

print(conn.list_streams())

print("Sending bill of rights to kinesis")
while True:
    conn.put_record('bill_of_rights', bill, 'bill_of_rights')
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
