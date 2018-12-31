import asyncore
import asynchat
import socket
import struct
import sys
import traceback

from wallaroo.experimental import connector_wire_messages as cwm

class AsyncServer(asynchat.async_chat, object):
    def __init__(self, handler_id, sock):
        print("AsyncServer.__init__", handler_id, sock)
        self._id = handler_id
        self._conn = sock
        super(AsyncServer, self).__init__(sock=self._conn)
        self.in_buffer = []
        self.out_buffer = []
        self.reading_header = True
        self.set_terminator(4) # first frame header
        self.in_handshake = True

    def collect_incoming_data(self, data):
        """Buffer the data"""
        self.in_buffer.append(data)

    def found_terminator(self):
        """Data is going to be in two parts:
        1. a 32-bit unsigned integer length header
        2. a payload of the size specified by (1)
        """
        if self.reading_header:
            # Read the header and set the terminator size for the payload
            self.reading_header = False
            h = struct.unpack(">I", b"".join(self.in_buffer))[0]
            self.in_buffer = []
            self.set_terminator(h)
        else:
            # Read the payload and pass it to _handle_frame
            frame_data = b"".join(self.in_buffer)
            self.in_buffer = []
            self.set_terminator(4) # read next frame header
            self.reading_header = True
            self._handle_frame(frame_data)

    def _handle_frame(self, frame):
        print("Received {!r}".format(frame))
        msg = cwm.Frame.decode(frame)
        print("got msg: {}".format(msg))
        # Hello, Ok, Error, Notify, NotifyAck, Message, Ack, Restart
        if isinstance(msg, cwm.Hello):
            # respond with an ok or an error
            ok = cwm.Ok(10, [])
            self.write(ok)
        elif isinstance(msg, cwm.Notify):
            # respond with notifyack
            notify_ack = cwm.NotifyAck(
                True if msg.stream_id % 2 == 0 else False,
                msg.stream_id,
                msg.point_of_ref * 10)
            self.write(notify_ack)
        elif isinstance(msg, cwm.Message):
            # no response, just print
            print("received message: {}".format(msg))
        elif isinstance(msg, cwm.Error):
            # Got error message from worker
            # close the connection and pass msg to the error handler
            self.close()
            raise Exception(msg.message)
        else:
            # write the original message back
            self.write(msg)

    def write(self, msg):
        print("write {}".format(msg))
        data = cwm.Frame.encode(msg)
        super(AsyncServer, self).push(data)

    def handle_error(self):
        _type, _value, _traceback = sys.exc_info()
        traceback.print_exception(_type, _value, _traceback)

    def close(self):
        print("Closing the connection")
        super(AsyncServer, self).close()


class EchoServer(asyncore.dispatcher):

    def __init__(self, host, port):
        asyncore.dispatcher.__init__(self)
        self.create_socket(family=socket.AF_INET, type=socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind((host, port))
        self.listen(10)
        self.count = 0

    def handle_accepted(self, sock, addr):
        print('Incoming connection from %s' % repr(addr))
        handler = AsyncServer(self.count, sock)
        self.count += 1

server = EchoServer('127.0.0.1', 8080)
print("server: ", server)
print("asyncore file: ", asyncore.__file__)
asyncore.loop()
