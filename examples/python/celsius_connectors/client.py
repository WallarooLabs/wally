import asyncore
import asynchat
import socket
import struct
import threading
import time

from wallaroo import connector_wire_messages as cwm

class AsyncClient(asynchat.async_chat):
    def __init__(self, host, port):
        conn = socket.socket()
        conn.connect( (host, port) )
        self._conn = conn
        asynchat.async_chat.__init__(self, sock=self._conn)
        self.in_buffer = []
        self.out_buffer = []
        self.reading_header = True
        self.set_terminator(4) # first frame header

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
            print("Received {!r}".format(b"".join(self.in_buffer)))
            self.in_buffer = []

    def _handle_frame(self, frame):



    def write(self, msg):
        print("write {}".format(msg))
        data = cwm.frame_encode(msg)
        asynchat.async_chat.push(self, data)


client = AsyncClient('127.0.0.1', 8080)
# start the loop in the background
t = threading.Thread(target=asyncore.loop)
t.daemon=True
t.start()

for x in range(30):
    client.push("The time is now {}".format(x).encode())
    time.sleep(.1)
print("stopping client")
