from __future__ import print_function
import sys

from boto import kinesis
from celsius_stream_def import CelsiusStream, parse_celsius_stream_addr
import time

shard_id = 'shardId-000000000000'
conn = kinesis.connect_to_region(region_name = "us-east-1")
shard_it = conn.get_shard_iterator('celsius-in', shard_id, "LATEST")["ShardIterator"]

celsius_stream_addr = parse_celsius_stream_addr(sys.argv)
extension = CelsiusStream(*celsius_stream_addr).extension()

while True:
    message = conn.get_records(shard_it, limit=2)
    for record in message["Records"]:
        extension.write(record["Data"])
    shard_it = message["NextShardIterator"]
    time.sleep(0.2)
