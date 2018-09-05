from __future__ import print_function
import os
import time
import sys
import socket

project = os.path.dirname(__file__)
bill_path = os.path.join(project, "data/bill_of_rights.txt")
with open(bill_path, 'r') as file:
    bill = file.read()

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

HOST = '127.0.0.1'
PORT = 30000

print("Sending data to udp host: " + HOST + " port: " + str(PORT))

while True:
    sock.sendto(bill, (HOST, PORT))
    print('.', end = '')
    sys.stdout.flush()
    time.sleep(0.5)
