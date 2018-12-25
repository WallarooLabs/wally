import asyncore
import asynchat
from collections import namedtuple
import socket
import struct
import sys
import threading
import time
import traceback

from wallaroo.experimental import (AtLeastOnceSourceConnector,
                                   connector_wire_messages as cwm,
                                   ProtocolError)



hello = cwm.Hello("version", "cookie", "program", "instance")
args = ['--application-module', 'celsius',
        '--connector', 'celsius_feed',
        '--celsius_feed-host', '127.0.0.1',
        '--celsius_feed-port', '7100',
        '--celsius_feed-timeout', '0.05']
client = AtLeastOnceSourceConnector(
        args=args,
        required_params=['host', 'port'],
        optional_params=['timeout', 'delay'])
client.initiate_handshake(hello)
client.start()

for x in range(10):
    client.write(cwm.Notify(x, str(x), x))
    time.sleep(.1)
for x in range(10):
    try:
        client.write(cwm.Message(
            stream_id = x,
            flags = 0,
            message_id = x*10,
            message = "Hello from stream_id {}, message_id {}".format(
                x, x*10)))
        time.sleep(.1)
    except ProtocolError, err:
        print(err.message)
print("stopping client")
client.write(cwm.Error("please close"))
time.sleep(1)
client.handle_close()
