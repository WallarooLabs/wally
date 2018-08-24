# Copyright 2018 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.

from select import select
import socket
import struct
import time


class SourceExtension(object):

    def __init__(self, encoder):
        self._encoder = encoder
        self._conn = None

    def connect(self, host, port):
        conn = socket.socket()
        print "Attempting to connect to {}:{}".format(host, port)
        while True:
            try:
                conn.connect((host, port))
                self._conn = conn
                return
            except socket.error as err:
                if err.errno == socket.errno.ECONNREFUSED:
                    time.sleep(1)
                else:
                    raise

    def write(self, message, partition=None, sequence=None):
        if self._conn == None:
            raise RuntimeError("Please call connect before writing")
        payload = self._encoder(message)
        self._conn.sendall(payload)


class SinkExtension(object):

    def __init__(self, decoder):
        self._decoder = decoder
        self._acceptor = None
        self._connections = []

    def listen(self, host, port, backlog = 0):
        acceptor = socket.socket()
        acceptor.bind((host, port))
        acceptor.listen(backlog)
        self._acceptor = acceptor
        self._connections.append(acceptor)

    def read(self, timeout=None):
        while True:
            readable, _, exceptional = select(self._connections, [], self._connections, timeout)
            for socket in exceptional:
                if socket is self._acceptor:
                    socket.close()
                    raise UnexpectedSocketError()
                else:
                    self._connections.remove(socket)
                    socket.close()
            for socket in readable:
                if socket is self._acceptor:
                    conn, _addr = socket.accept()
                    conn.setblocking(0)
                    self._connections.append(conn)
                else:
                    header = socket.recv(self._decoder.header_length(), socket.MSG_WAITALL)
                    if not header:
                        socket.close()
                        self._connections.remove(socket)
                        return None
                    expected = self._decoder.payload_length(header)
                    data = socket.recv(expected, socket.MSG_WAITALL)
                    return self._decoder._message_decoder(data)


class UnexpectedSocketError(Exception):
    pass
