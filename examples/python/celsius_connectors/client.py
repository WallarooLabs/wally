import asyncore
import asynchat
from collections import namedtuple
import socket
import struct
import threading
import time

from wallaroo.experimental import connector_wire_messages as cwm


class ConnectorError(Exception):
    pass


class ProtocolError(Exception):
    pass


Stream = namedtuple('Stream', ['id', 'name', 'point_of_ref', 'is_open'])


class AsyncClient(threading.Thread, asynchat.async_chat, object):
    def __init__(self, host, port):
        # connection details
        self.host = host
        self.port = port
        self.credits = 0

        # Stream details
        self._streams = {}  # stream_id: Stream

        self.handshake_complete = False
        self.in_buffer = []
        self.out_buffer = []
        self.reading_header = True
        self.set_terminator(4) # first frame header

        # Thread details
        threading.Thread.__init__(self)
        self.daemon = True

    ###########################
    # Incoming communications #
    ###########################

    def run(self):
        # only allow starting after handshake is complete
        if not self.handshake_complete:
            raise ProtocolError("Cannot start async loop before handshake"
                                " is complete")
        asyncore.loop()

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
            self.set_terminator(4) # read next frame header
            self.reading_header = True
            frame = b"".join(self.in_buffer)
            self.in_buffer = []
            self._handle_frame(frame)

    def _handle_frame(self, frame):
        print("Received {!r}".format(frame))
        msg = cwm.Frame.decode(frame)
        print("got msg: {}".format(msg))
        # Ok, Error, NotifyAck, Ack, Restart
        if isinstance(msg, cwm.Ok):
            self._handle_ok(msg)
        elif isinstance(msg, cwm.Error):
            # Got error message from worker
            # close the connection and pass it to the error handler
            self.close()
            raise ConnectorError(msg.message)
        elif isinstance(msg, cwm.NotifyAck):
            self._handle_notify_ack(msg)
        elif isinstance(msg, cwm.Ack):
            self._handle_ack(msg)
        elif isinstance(msg, Restart):
            self.handle_restart(msg)
        else: # handle invalid message
            self.handle_invalid_message(msg)

    def _handle_ok(self, msg):
        if not self.in_handshake:
            self.close()
            raise ProtocolError("Got an Ok message outside of a"
                                " handshake")
        else:
            # deposit the credits
            self.credits += msg.initial_credits
            for stream_id, stream_name, point_of_ref in msg.credit_list:
                self.update_stream(stream_id,
                                   stream_name = stream_name,
                                   point_of_ref = point_of_ref,
                                   is_open = False)
            # set handshake_complete
            self.handshake_complete = True
            # set terminator to 4
            self.set_terminator(4)
            # set socket to nonblocking
            self._conn.setblocking(0)
            # initialize the asynchat handler
            asynchat.async_chat.__init__(self, sock=self._conn)

    def _handle_notify_ack(self, msg):
        self.update_stream(msg.stream_id,
                           point_of_ref = msg.point_of_ref,
                           is_open = msg.notify_success)

    def _handle_ack(self, msg):
        self.credits += msg.credits
        for (stream_id, point_of_ref) in msg.acks:
            self.update_stream(stream_id,
                               point_of_ref = point_of_ref)

    def update_stream(self, stream_id, stream_name=None,
                      point_of_ref=None, is_open=None):
        old = self._streams.get(stream_id, None)
        if old is None:
            new = Stream(stream_id, stream_name, point_of_ref, is_open)
        else:
            if stream_name is not None:
                if old.name != steam_name:
                    # stream collision... throw error and close connection
                    raise ConnectorError("Got wrong stream name for "
                                         "stream. Expected {} but got {}."
                                         .format(old.name, stream_name))
            new = Stream(stream_id,
                         old.name if old is not None else stream_name,
                         (point_of_ref if point_of_ref is not None else
                          old.point_of_ref),
                         is_open if is_open is not None else old.is_open)
        # update the stream information
        self._streams[stream_id] = new
        # Call optional user handler with updated stream
        self.stream_updated(new)

    ##########################
    # Outoing communications #
    ##########################

    def initiate_handshake(self, hello):
        conn = socket.socket()
        conn.connect( (self.host, self.port) )
        self._conn = conn

        self.in_handshake = True
        self.version = hello.version
        self.cookie = hello.cookie
        self.program_name = hello.program_name
        self.instance_name = hello.instance_name
        self._conn.setblocking(1) # Set socket to blocking mode
        self._conn.sendall(cwm.Frame.encode(hello))
        header_bytes = self._conn.recv(4)
        frame_size = struct.unpack('>I', header_bytes)[0]
        frame = self._conn.recv(frame_size)
        self._handle_frame(frame)

    def write(self, msg):
        print("write {}".format(msg))
        if not self.is_alive():
            raise ConnectorError("Can't write to a closed conection")
        if (isinstance(msg, cwm.Error) or
            (msg.stream_id in self._streams and
            self._streams[msg.stream_id].is_open)):
            data = cwm.Frame.encode(msg)
            super(AsyncClient, self).push(data)
        else:
            raise ProtocolError("Message cannot be sent. Stream ({}) is not "
                                "in an open state. Use notify() to open it."
                                .format(msg.stream_id))

    def notify(self, stream_id, stream_name=None, point_of_ref=None):
        old = self._streams.get(stream_id, None)
        if old:
            if point_of_ref is None:
                raise ConnectorError("Cannot update a stream without a valid "
                                     "point_of_ref value")
            new = Stream(stream_id,
                         old.name if old is not None else stream_name,
                         (point_of_ref if point_of_ref is not None else
                          old.point_of_ref),
                         old.is_open)
        else:
            if stream_name is None:
                raise ConnectorError("Cannot notify a new stream without "
                                     "a Stream name!")
            new = Stream(stream_id,
                         stream_name,
                         0 if point_of_ref is None else point_of_ref,
                         False)
        # update locally
        self._streams[stream_id] = new
        # send to wallaroo worker
        self.write(cwm.Notify(new.stream_id,
                              new.stream_name,
                              new.point_of_ref))

    ########################
    # User defined methods #
    ########################

    def stream_updated(self, stream_id=None, steam_name=None,
                       point_of_ref=None, is_open=None):
        """
        User handler can handle updates to their streams here.
        Updates may include:
            - stream has been closed (Stream.is_open = False)
            - stream has been open (Stream.is_open = True)
            - point of reference has been updated (either forward or back!)
        """
        pass

    def handle_restart(self):
        pass

    def handle_error(self, msg):
        print("handling error: {}".format(msg))
        super(AsyncClient, self).handle_error(msg)


#import socket
#s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
#s.connect(('localhost', 50000))
#s.sendall('Hello, world')
#data = s.recv(1024)
#s.close()
#print 'Received', repr(data)



hello = cwm.Hello("version", "cookie", "program", "instance")
client = AsyncClient('127.0.0.1', 8080)
client.initiate_handshake(hello)
client.start()

for x in range(10):
    client.write(cwm.Error("The time is now {}".format(x)))
    time.sleep(.1)
print("stopping client")
client.handle_close()
