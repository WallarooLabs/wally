#!/usr/bin/env python

import socket
import struct
import sys
opts = list()

hostport = sys.argv[1].split(":")

sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
server_address = (hostport[0], int(hostport[1]))
print('Sending to {!r}'.format(server_address))
sock.connect(server_address)

try:
#    for i in range(1000,2000):
    i = 1111
    bin_i = struct.pack(">I",i)
    sock.sendall(struct.pack(">I",4) + bin_i)

finally:
   print('Done sending')
   sock.close()
