from __future__ import print_function

import sys
import time

import boto3
from text_documents import TextStream, parse_text_stream_addr

shard_id = 'shardId-000000000000'
conn = boto3.client('kinesis')
shard_it = conn.get_shard_iterator(
    StreamName='bill_of_rights', ShardId=shard_id, ShardIteratorType="LATEST")["ShardIterator"]

text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()

while True:
    message = conn.get_records(ShardIterator=shard_it, Limit=2)
    for record in message["Records"]:
        extension.write(record["Data"])
    shard_it = message["NextShardIterator"]
    time.sleep(0.2)
