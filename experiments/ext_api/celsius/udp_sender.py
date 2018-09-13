from __future__ import print_function
import threading
import sys
import socket

from farenheit_stream_def import FarenheitStream, parse_farenheit_stream_addr
from udp_parser import parse_udp_params

farenheit_stream_addr = parse_farenheit_stream_addr(sys.argv)
extension = FarenheitStream(*farenheit_stream_addr).extension()
params = parse_udp_params(sys.argv)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print("sending to host: " + params.udp_host + " port: " + str(params.udp_port))

while True:
    farenheit_value = extension.read()
    sock.sendto(farenheit_value + "\n", (params.udp_host, params.udp_port))
