from __future__ import print_function

import os
import sys
import time

import boto3

conn = boto3.client('kinesis')

project = os.path.dirname(__file__)
bill_path = os.path.join(project, "data/bill_of_rights.txt")
with open(bill_path, 'r') as file:
    bill = file.read()


print("Creating Kinesis Stream")
pass

print(conn.list_streams())

print("Sending bill of rights to kinesis")
while True:
    conn.put_record(StreamName='bill_of_rights', Data=bill, PartitionKey='bill_of_rights')
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
