from __future__ import print_function
import pika
import sys

from wallaroo.contrib.amqp import parse_amqp_params, AsyncConsumer
from text_documents import TextStream, parse_text_stream_addr


def handle_text(message):
	extension.write(message)


params = parse_amqp_params(sys.argv)
text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()
consumer = AsyncConsumer(params.amqp_url, 'text', handle_text)
consumer.run()
