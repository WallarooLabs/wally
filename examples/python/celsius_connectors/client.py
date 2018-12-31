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



# TODO: call source class init with required_params, etc, like in udp_source
hello = cwm.Hello("version", "cookie", "program", "instance")
client = AtLeastOnceSourceConnector('127.0.0.1', 8080)
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
