from __future__ import print_function

import sys
import threading

import boto3
from word_counts import CountStream, parse_count_stream_addr

count_stream_addr = parse_count_stream_addr(sys.argv)
extension = CountStream(*count_stream_addr).extension()
s3 = boto3.client('s3')
bucket_name = 'wallaroowordcountexample'
s3.create_bucket(Bucket=bucket_name)

while True:
    word, count = extension.read()
    s3.put_object(Bucket=bucket_name, Body=str(count), Key=word, ACL='authenticated-read')
