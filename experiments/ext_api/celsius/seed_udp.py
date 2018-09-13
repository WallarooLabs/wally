from __future__ import print_function
import os
import time
import sys
import socket

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

HOST = '127.0.0.1'
PORT = 30000

print("Sending data to udp host: " + HOST + " port: " + str(PORT))

i = 0

while True:
    sock.sendto(str(i).encode("utf-8"), (HOST, PORT))
    i = i + 1
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
