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

import argparse
import inspect
import socket
import struct
import sys
import time

from functools import wraps
from select import select

import wallaroo


def stream_message_decoder(func):
    wallaroo._validate_arity_compatability(func, 1)
    C = wallaroo._wallaroo_wrap(func.__name__, func, wallaroo.ConnectorDecoder)
    return C()


def stream_message_encoder(func):
    wallaroo._validate_arity_compatability(func, 1)
    C = wallaroo._wallaroo_wrap(func.__name__, func, wallaroo.ConnectorEncoder)
    return C()


class StreamDecoderError(Exception):
    pass


class SourceConnectorConfig(object):
    def __init__(self, host, port, decoder):
        self._host = host
        self._port = port
        self._decoder = decoder

    def to_tuple(self):
        return ("connector", self._host, str(self._port), self._decoder)


class SinkConnectorConfig(object):
    def __init__(self, host, port, encoder):
        self._host = host
        self._port = port
        self._encoder = encoder

    def to_tuple(self):
        return ("connector", self._host, str(self._port), self._encoder)


class SourceConnector(object):
    def __init__(self, args=None, required_params=[], optional_params=[]):
        params = parse_connector_args(args or sys.argv, required_params, optional_params)
        wallaroo_app = __import__(params.application)
        actions = wallaroo_app.application_setup(args or sys.argv)
        try:
            (_command, _name, port, encoder, _decoder) = next(
                action for action in actions
                if action[0] == "source_connector" and action[1] == params.connector_name)
        except:
            print("Unable to find a source connector with the name " + params.connector_name)
            exit(-1)
        self.params = params
        self._encoder = encoder
        self._host = '127.0.0.1'
        self._port = port
        self._conn = None

    def connect(self, host=None, port=None):
        while True:
            try:
                conn = socket.socket()
                conn.connect( (host or self._host, int(port or self._port)) )
                self._conn = conn
                return
            except socket.error as err:
                if err.errno == socket.errno.ECONNREFUSED:
                    time.sleep(1)
                else:
                    raise

    def write(self, message):
        # Future parameters
        partition = None
        sequence = None
        if self._conn == None:
            raise RuntimeError("Please call connect before writing")
        payload = self._encoder.encode(message)
        self._conn.sendall(payload)


class SinkConnector(object):

    def __init__(self, args=None, required_params=[], optional_params=[]):
        params = parse_connector_args(args or sys.argv, required_params, optional_params)
        wallaroo_app = __import__(params.application)
        actions = wallaroo_app.application_setup(args or sys.argv)
        try:
            (_command, _name, port, _encoder, decoder) = next(
                action for action in actions
                if action[0] == "sink_connector" and action[1] == params.connector_name)
        except:
            print("Unable to find a sink connector with the name " + params.connector_name)
            exit(-1)
        self.params = params
        self._decoder = decoder
        self._host = '127.0.0.1'
        self._port = port
        self._acceptor = None
        self._connections = []
        self._buffers = {}
        self._pending = []

    def listen(self, host=None, port=None, backlog=0):
        acceptor = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        acceptor.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
        acceptor.bind((host or self._host, int(port or self._port)))
        acceptor.listen(backlog)
        self._acceptor = acceptor
        self._connections.append(acceptor)

    def read(self, timeout=None):
        while True:
            for socket in self._pending:
                ok, message = self._read_one(socket)
                if ok: return message
            self._select_any(timeout)

    def _select_any(self, timeout=None):
        readable, _, exceptional = select(self._connections, [], self._connections, timeout)
        for socket in exceptional:
            if socket is self._acceptor:
                socket.close()
                raise UnexpectedSocketError()
            else:
                self._teardown_connection(socket)
        for socket in readable:
            if socket is self._acceptor:
                conn, _addr = socket.accept()
                self._setup_connection(conn)
            else:
                buffered = self._buffers[socket] + socket.recv(4096)
                self._buffers[socket] = buffered
                self._pending.append(socket)

    def _read_one(self, socket):
        buffered = self._buffers[socket]
        header_len = self._decoder.header_length()
        if len(buffered) < header_len:
            self._buffers[socket] = buffered
            return (False, None)
        expected = self._decoder.payload_length(buffered[:header_len])
        if len(buffered) < header_len + expected:
            self._buffers[socket] = buffered
            return (False, None)
        data = buffered[header_len:header_len+expected]
        buffered = buffered[header_len + expected:]
        self._buffers[socket] = buffered
        if len(buffered) < header_len:
            self._pending.remove(socket)
        return (True, self._decoder.decode(data))

    def _setup_connection(self, conn):
        conn.setblocking(0)
        self._connections.append(conn)
        self._buffers[conn] = b""

    def _teardown_connection(self, conn):
        self._connections.remove(conn)
        del self._buffers[conn]
        conn.close()


class UnexpectedSocketError(Exception):
    pass


def parse_connector_args(args, required_params=[], optional_params=[]):
    connector_prefix = _parse_connector_prefix(args) or 'CONNECTOR_NAME'
    parser = argparse.ArgumentParser()
    parser.add_argument('--application-module', dest='application', required=True)
    parser.add_argument('--connector', dest='connector_name', required=True)
    for key in required_params:
        parser.add_argument('--{}-{}'.format(connector_prefix, key), dest=key, required=True)
    for key in optional_params:
        parser.add_argument('--{}-{}'.format(connector_prefix, key), dest=key)
    params = parser.parse_known_args(args)[0]
    return params


def _parse_connector_prefix(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--connector', dest='connector_name')
    params = parser.parse_known_args(args)[0]
    return params.connector_name
