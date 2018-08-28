import argparse

def parse_amqp_params(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--amqp-url', dest='amqp_url', default='amqp://guest:guesst@localhost:5672/%2F')
    parser.add_argument('--queue', dest='queues', action='append')
    params = parser.parse_known_args(args)[0]
    return params


class AsyncConsumer(object):

    def __init__(self, amqp_url, queue, message_handler, exchange=None, exchange_type=None, routing_key=None):
        self._connection = None
        self._channel = None
        self._closing = False
        self._consumer_tag = None
        self._url = amqp_url
        self._queue = queue
        self._handle_message = message_handler
        self._exchange = exchange
        self._exchange_type = exchange_type
        self._routing_key = routing_key

    def connect(self):
        return pika.SelectConnection(
        	pika.URLParameters(self._url),
            self.on_connection_open,
            stop_ioloop_on_close=False
        )

    def on_connection_open(self, unused_connection):
        self.add_on_connection_close_callback()
        self.open_channel()

    def add_on_connection_close_callback(self):
        self._connection.add_on_close_callback(self.on_connection_closed)

    def on_connection_closed(self, connection, reply_code, reply_text):
        self._channel = None
        if self._closing:
            self._connection.ioloop.stop()
        else:
            self._connection.add_timeout(5, self.reconnect)

    def reconnect(self):
        self._connection.ioloop.stop()
        if not self._closing:
            self._connection = self.connect()
            self._connection.ioloop.start()

    def open_channel(self):
        self._connection.channel(on_open_callback=self.on_channel_open)

    def on_channel_open(self, channel):
        self._channel = channel
        self.add_on_channel_close_callback()
        if self._exchange:
        	self.setup_exchange(self._exchange)

    def add_on_channel_close_callback(self):
        self._channel.add_on_close_callback(self.on_channel_closed)

    def on_channel_closed(self, channel, reply_code, reply_text):
        self._connection.close()

    def setup_exchange(self, exchange_name):
        self._channel.exchange_declare(
        	self.on_exchange_declareok,
            exchange_name,
            self._exchange_type
        )

    def on_exchange_declareok(self, unused_frame):
        self.setup_queue(self._queue)

    def setup_queue(self, queue_name):
        self._channel.queue_declare(self.on_queue_declareok, queue_name)

    def on_queue_declareok(self, method_frame):
        self._channel.queue_bind(
        	self.on_bindok,
        	self._queue,
            self._exchange,
            self._routing_key
        )

    def on_bindok(self, unused_frame):
        self.start_consuming()

    def start_consuming(self):
        self.add_on_cancel_callback()
        self._consumer_tag = self._channel.basic_consume(self.on_message,
                                                         self._queue)

    def add_on_cancel_callback(self):
        self._channel.add_on_cancel_callback(self.on_consumer_cancelled)

    def on_consumer_cancelled(self, method_frame):
        if self._channel:
            self._channel.close()

    def on_message(self, unused_channel, basic_deliver, properties, body):
        self.acknowledge_message(basic_deliver.delivery_tag)
        self.handle_message(body)

    def acknowledge_message(self, delivery_tag):
        self._channel.basic_ack(delivery_tag)

    def stop_consuming(self):
        if self._channel:
            self._channel.basic_cancel(self.on_cancelok, self._consumer_tag)

    def on_cancelok(self, unused_frame):
        self.close_channel()

    def close_channel(self):
        self._channel.close()

    def run(self):
        self._connection = self.connect()
        self._connection.ioloop.start()

    def stop(self):
        self._closing = True
        self.stop_consuming()
        self._connection.ioloop.start()

    def close_connection(self):
        self._connection.close()
