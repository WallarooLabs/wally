import asyncore
import socket
import struct

class EchoHandler(asyncore.dispatcher_with_send):

    def handle_read(self):
        data = self.recv(8192)
        if data:
            print("Received {!r}".format(data))
            response = "Received {} bytes".format(len(data)).encode()
            data = struct.pack('>I{}s'.format(len(response)), len(response),
                    response)
            self.send(data)

    def send(self, data):
        print("sending {!r}".format(data))
        super(EchoHandler, self).send(data)

class EchoServer(asyncore.dispatcher):

    def __init__(self, host, port):
        asyncore.dispatcher.__init__(self)
        self.create_socket(family=socket.AF_INET, type=socket.SOCK_STREAM)
        self.set_reuse_addr()
        self.bind((host, port))
        self.listen(1)

    def handle_accepted(self, sock, addr):
        print('Incoming connection from %s' % repr(addr))
        handler = EchoHandler(sock)

server = EchoServer('127.0.0.1', 8080)
print("server: ", server)
print("asyncore file: ", asyncore.__file__)
asyncore.loop()
