from __future__ import print_function
import threading
import sys
import socket

from word_counts import CountStream, parse_count_stream_addr
from udp_parser import parse_udp_params

count_stream_addr = parse_count_stream_addr(sys.argv)
extension = CountStream(*count_stream_addr).extension()
params = parse_udp_params(sys.argv)

sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)

print("sending to host: " + params.udp_host + " port: " + str(params.udp_port))

while True:
    word, count = extension.read()
    sock.sendto(word + " => " + str(count) + "\n", (params.udp_host, params.udp_port))
