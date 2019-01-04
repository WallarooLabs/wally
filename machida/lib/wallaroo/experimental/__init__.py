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
import asynchat
import asyncore
from collections import namedtuple
from datetime import datetime
import inspect
from select import select
import socket
import struct
import sys
import threading
import time
import traceback

# A note on import dependencies:
# This only works if `machida/lib/` is in your PYTHONNPATH. This is fine here
# because you can't use wallaroo without that anyway.
# Anyway, don't use relative imports here.
import wallaroo
from wallaroo import dt_to_timestamp
from  . import connector_wire_messages as cwm


class ConnectorError(Exception):
    pass


class ProtocolError(Exception):
    pass


def stream_message_decoder(func):
    wallaroo._validate_arity_compatability(func.__name__, func, 1)
    C = wallaroo._wallaroo_wrap(func.__name__, func, wallaroo.ConnectorDecoder)
    return C()


def stream_message_encoder(func):
    wallaroo._validate_arity_compatability(func.__name__, func, 1)
    C = wallaroo._wallaroo_wrap(func.__name__, func, wallaroo.ConnectorEncoder)
    return C()


class SourceConnectorConfig(object):
    def __init__(self, name, encoder, decoder, port, host='127.0.0.1'):
        self._name = name
        self._host = host
        self._port = port
        self._encoder = encoder
        self._decoder = decoder

    def to_tuple(self):
        return ("source_connector", self._name, self._host, str(self._port), self._encoder, self._decoder)


class SinkConnectorConfig(object):
    def __init__(self, name, encoder, decoder, port, host='127.0.0.1'):
        self._name = name
        self._host = host
        self._port = port
        self._encoder = encoder
        self._decoder = decoder

    def to_tuple(self):
        return ("sink_connector", self._name, self._host, str(self._port), self._encoder, self._decoder)


class BaseConnector(object):
    def __init__(self, args=None, required_params=[], optional_params=[]):
        params = parse_connector_args(args or sys.argv, required_params, optional_params)
        wallaroo_mod = __import__(params.application)
        application = wallaroo_mod.application_setup(args or sys.argv)
        source = None
        for stage in application[2]:
            for step in stage:
                if step[0] == 'source' and step[2][0] == 'source_connector' and step[2][1] == params.connector_name:
                    source = step[2]
        if source is None:
            raise RuntimeError("Unable to find a source connector with the name " + params.connector_name)
        (_, _name, host, port, encoder, _decoder) = source
        self.params = params
        self._encoder = encoder
        self._host = host
        self._port = port


class SourceConnector(BaseConnector):
    def __init__(self, args=None, required_params=['host', 'port'],
                 optional_params=[]):
        super(SourceConnector, self).__init__(args, required_params,
                                              optional_params)
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

    def write(self, message, event_time=0, key=None):
        if self._conn == None:
            raise RuntimeError("Please call connect before writing")
        payload = self._encoder.encode(message, event_time, key)
        self._conn.sendall(payload)


Stream = namedtuple('Stream', ['id', 'name', 'point_of_ref', 'is_open'])


class AtLeastOnceSourceConnector(threading.Thread, asynchat.async_chat, BaseConnector):
    # TODO :
    # 1. implement credits based flow control
    # 2. revisit parse_connector_args
    # The way we require host and port args, but then get them from the app topo
    # and ignore the ones in the parsed params object is confusing and doesn't
    # make much sense to me. Ping Brian before making changes to this.

    def __init__(self, args=None, required_params=['host', 'port'],
                 optional_params=['timeout']):
        # Use BaseConnector to do any argument parsing
        BaseConnector.__init__(self, args, required_params, optional_params)

        # connection details are given from the base
        self._port = int(self._port)  # but convert port to int
        self.credits = 0
        if self.params.timeout:
            self._timeout = float(self.params.timeout)
        else:
            self._timeout = 0.05

        # Stream details
        self._streams = {}  # stream_id: Stream

        self.handshake_complete = False
        self.in_buffer = []
        self.out_buffer = []
        self.reading_header = True
        self.set_terminator(4) # first frame header
        self.error = None

        # Thread details
        threading.Thread.__init__(self)
        self.daemon = True

    ###########################
    # Incoming communications #
    ###########################

    def run(self):
        # only allow starting after handshake is complete
        if not self.handshake_complete:
            raise ProtocolError("Cannot start async loop before handshake"
                                " is complete")
        asyncore.loop(timeout=self._timeout)

    def collect_incoming_data(self, data):
        """Buffer the data"""
        self.in_buffer.append(data)

    def found_terminator(self):
        """Data is going to be in two parts:
        1. a 32-bit unsigned integer length header
        2. a payload of the size specified by (1)
        """
        if self.reading_header:
            # Read the header and set the terminator size for the payload
            self.reading_header = False
            h = struct.unpack(">I", b"".join(self.in_buffer))[0]
            self.in_buffer = []
            self.set_terminator(h)
        else:
            # Read the payload and pass it to _handle_frame
            self.set_terminator(4) # read next frame header
            self.reading_header = True
            frame = b"".join(self.in_buffer)
            self.in_buffer = []
            self._handle_frame(frame)

    def _handle_frame(self, frame):
        msg = cwm.Frame.decode(frame)
        # Ok, Error, NotifyAck, Ack, Restart
        if isinstance(msg, cwm.Ok):
            self._handle_ok(msg)
        elif isinstance(msg, cwm.Error):
            # Got error message from worker
            # close the connection and pass msg to the error handler but only
            # if not in handshake. If in handshake, let the initiate_handshake
            # function deal with this.
            if not self.in_handshake:
                self.close()
            raise ConnectorError(msg.message)
        elif isinstance(msg, cwm.NotifyAck):
            self._handle_notify_ack(msg)
        elif isinstance(msg, cwm.Ack):
            self._handle_ack(msg)
        elif isinstance(msg, cwm.Restart):
            self.handle_restart()
        # messages that should only go connector->wallaroo
        # Notify, Hello, Message
        elif isinstance(msg, (cwm.Hello, cwm.Message, cwm.Notify)):
            # close and raise error
            self.close()
            raise ProtocolError(
                "{} should never be received at the connector.".format(msg))
        else: # handle unknown messages
            self.handle_invalid_message(msg, close=False)

    def _handle_ok(self, msg):
        if not self.in_handshake:
            self.close()
            raise ProtocolError("Got an Ok message outside of a"
                                " handshake")
        else:
            # deposit the credits
            self.credits += msg.initial_credits
            for stream_id, stream_name, point_of_ref in msg.credit_list:
                self.update_stream(stream_id,
                                   stream_name = stream_name,
                                   point_of_ref = point_of_ref,
                                   is_open = False)
            # set handshake_complete
            self.handshake_complete = True
            # set terminator to 4
            self.set_terminator(4)
            # set socket to nonblocking
            self._conn.setblocking(0)
            # initialize the asynchat handler
            asynchat.async_chat.__init__(self, sock=self._conn)

    def _handle_notify_ack(self, msg):
        self.update_stream(msg.stream_id,
                           point_of_ref = msg.point_of_ref,
                           is_open = msg.notify_success)

    def _handle_ack(self, msg):
        self.credits += msg.credits
        for (stream_id, point_of_ref) in msg.acks:
            self.update_stream(stream_id,
                               point_of_ref = point_of_ref)

    def update_stream(self, stream_id, stream_name=None,
                      point_of_ref=None, is_open=None):
        old = self._streams.get(stream_id, None)
        if old is None:
            new = Stream(stream_id, stream_name, point_of_ref, is_open)
        else:
            if stream_name is not None:
                if old.name != stream_name:
                    # stream collision... throw error and close connection
                    raise ConnectorError("Got wrong stream name for "
                                         "stream. Expected {} but got {}."
                                         .format(old.name, stream_name))
            new = Stream(stream_id,
                         old.name if old is not None else stream_name,
                         (point_of_ref if point_of_ref is not None else
                          old.point_of_ref),
                         is_open if is_open is not None else old.is_open)
        # update the stream information
        self._streams[stream_id] = new
        # Call optional user handler with updated stream
        self.stream_updated(new)

    ##########################
    # Outoing communications #
    ##########################

    def initiate_handshake(self, hello):
        conn = socket.socket()
        conn.connect( (self._host, self._port) )
        self._conn = conn

        self.in_handshake = True
        self.version = hello.version
        self.cookie = hello.cookie
        self.program_name = hello.program_name
        self.instance_name = hello.instance_name
        self._conn.setblocking(1) # Set socket to blocking mode
        self._conn.sendall(cwm.Frame.encode(hello))
        header_bytes = self._conn.recv(4)
        frame_size = struct.unpack('>I', header_bytes)[0]
        frame = self._conn.recv(frame_size)
        try:
            self._handle_frame(frame)
        except Exception as err:
            # close the connection and raise the error
            self._conn.close()
            raise err

    def write(self, msg):
        if not self.is_alive():
            if self.error:
                raise self.error
            else:
                raise ConnectorError("Can't write to a closed conection")
        if (isinstance(msg, (cwm.Error, cwm.Notify)) or
            (msg.stream_id in self._streams and
            self._streams[msg.stream_id].is_open)):
            data = cwm.Frame.encode(msg)
            self._write(data)
        else:
            raise ProtocolError("Message cannot be sent. Stream ({}) is not "
                                "in an open state. Use notify() to open it."
                                .format(msg.stream_id))

    def _write(self, data):
        """
        Replaces asynchat.async_chat.push, which does a synchronous send
        i.e. without calling `initiate_send()` at the end
        """
        sabs = self.ac_out_buffer_size
        if len(data) > sabs:
            for i in xrange(0, len(data), sabs):
                self.producer_fifo.append(data[i:i+sabs])
        else:
            self.producer_fifo.append(data)

    def pending_sends(self):
        """
        Are there any pending sends
        """
        if len(self.producer_fifo) > 0:
            return True
        else:
            return False

    def notify(self, stream_id, stream_name=None, point_of_ref=None):
        old = self._streams.get(stream_id, None)
        if old:
            if point_of_ref is None:
                raise ConnectorError("Cannot update a stream without a valid "
                                     "point_of_ref value")
            new = Stream(stream_id,
                         old.name if old is not None else stream_name,
                         (point_of_ref if point_of_ref is not None else
                          old.point_of_ref),
                         old.is_open)
        else:
            if stream_name is None:
                raise ConnectorError("Cannot notify a new stream without "
                                     "a Stream name!")
            new = Stream(stream_id,
                         stream_name,
                         0 if point_of_ref is None else point_of_ref,
                         False)
        # update locally
        self._streams[stream_id] = new
        # send to wallaroo worker
        self.write(cwm.Notify(new.id,
                              new.name,
                              new.point_of_ref))

    def end_of_stream(self, stream_id, event_time=None, key=None):
        """
        Send an EOS message for a stream_id, with an optional key and
        event_time.
        event_time must be either a datetime or a float of seconds since
        epoch (it may be negtive for dates before 1970-1-1)
        """
        flags = cwm.Message.Eos | cwm.Message.Ephemeral
        if event_time is not None:
            flags |= cwm.Message.EventTime
            if isinstance(event_time, datetime):
                ts = dt_to_timestamp(event_time)
            elif isinstance(event_time, (int, float)):
                ts = event_time
            else:
                raise ProtocolError("Event_time must be a datetime or a float")
        else:
            ts = None
        if key:
            flags |= cw.Message.key
            if isinstance(key, bytes):
                en_key = key
            else:
                en_key = key.encode()
        else:
            en_key = None
        msg = cwm.Message(
            stream_id = stream_id,
            flags = flags,
            message_id = None,
            event_time = ts,
            key = en_key,
            message = None)
        self.write(msg)

    ########################
    # User defined methods #
    ########################

    def stream_updated(self, stream):
        """
        User handler can handle updates to their streams here.
        Updates may include:
            - stream has been closed (Stream.is_open = False)
            - stream has been open (Stream.is_open = True)
            - point of reference has been updated (either forward or back!)
        """
        pass

    def handle_invalid_message(self, msg):
        print("WARNING: {}".format(ProtocolError(
            "Received an unrecognized message: {}".format(msg))))
        pass

    def handle_restart(self):
        # TODO:
        # 1. close the connection
        # 2. start new handshake
        # 3. notify all current streams
        #    cannot assume that any messages sent with message_id's larger
        #    than those last acked (e.g. last point_of_ref in self._streams)
        #    have been processed.
        # TODO: should we reset streams to last acked point, or wait for the
        #       worker to respond to the notify acks? Or at least to the `Ok`?
        #       What if once reconnected, not all streams in self._streams`
        #       show up in the Ok message?
        print("Got RESTART... now what?")
        raise ProtocolError("Don't know what to do with restart!")
        pass

    def handle_error(self):
        """
        Default error handler: print a normal error traceback to sys.stderr
        and close the connection.

        Users may override this with custom handlers

        e.g. trigger a callback in the user class to stop a TCP server

        ```python
        class MyTCPServer(AsyncClient):
            def handle_error(self):
                # print the error using the subclass method
                super(MyTCPServer, self).handle_error()
                # Stop MyTCPServer as well
                self.stop_server()
        ```
        """
        _type, _value, _traceback = sys.exc_info()
        traceback.print_exception(_type, _value, _traceback)
        print("ERROR: Closing the connection after encountering an error")
        self.error = _value
        self.close()


class SinkConnector(object):

    def __init__(self, args=None, required_params=[], optional_params=[]):
        params = parse_connector_args(args or sys.argv, required_params, optional_params)
        wallaroo_mod = __import__(params.application)
        application = wallaroo_mod.application_setup(args or sys.argv)
        sink = None
        for stage in application[2]:
            for step in stage:
                if step[0] == 'to_sink' and step[1][0] == 'sink_connector' and step[1][1] == params.connector_name:
                    sink = step[1]
        if sink is None:
            raise RuntimeError("Unable to find a sink connector with the name " + params.connector_name)
        (_, _name, host, port, _encoder, decoder) = sink
        self.params = params
        self._decoder = decoder
        self._host = host
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
