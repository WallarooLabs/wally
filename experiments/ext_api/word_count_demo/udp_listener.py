from __future__ import print_function
import sys
import SocketServer

from text_documents import TextStream, parse_text_stream_addr
from udp_parser import parse_udp_params

class MyUDPHandler(SocketServer.BaseRequestHandler):
    def handle(self):
        data = self.request[0].strip()
        extension.write(data)

params = parse_udp_params(sys.argv)
text_stream_addr = parse_text_stream_addr(sys.argv)
extension = TextStream(*text_stream_addr).extension()

print("listening on host: " + params.udp_host + " port: " + str(params.udp_port))
server = SocketServer.UDPServer((params.udp_host, params.udp_port), MyUDPHandler)
server.serve_forever()

