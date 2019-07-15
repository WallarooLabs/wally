from __future__ import unicode_literals
import struct
import itertools

try:
    from StringIO import StringIO
except ImportError:
    from io import BytesIO as StringIO


class Hello(object):
    """
    Hello(version: String, cookie: String, program_name: String,
          instance_name: String)
    """
    def __init__(self, version, cookie, program_name, instance_name):
        self.version = version
        self.cookie = cookie
        self.program_name = program_name
        self.instance_name = instance_name

    def __str__(self):
        return ("Hello(version={!r}, cookie={!r}, program_name={!r}, "
                "instance_name={!r})"
                .format(self.version, self.cookie, self.program_name,
                        self.instance_name))

    def __eq__(self, other):
        return (self.version == other.version and
                self.cookie == other.cookie and
                self.program_name == other.program_name and
                self.instance_name == other.instance_name)

    def encode(self):
        v, c, p, i = map(lambda x: x.encode(),
                         (self.version,
                          self.cookie,
                          self.program_name,
                          self.instance_name))
        return struct.pack(">H{}sH{}sH{}sH{}s"
                           .format(*map(len, (v, c, p, i))),
                           len(v), v,
                           len(c), c,
                           len(p), p,
                           len(i), i)

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        version_length = struct.unpack(">H", reader.read(2))[0]
        version = reader.read(version_length).decode()
        cookie_length = struct.unpack(">H", reader.read(2))[0]
        cookie = reader.read(cookie_length).decode()
        program_name_length = struct.unpack(">H", reader.read(2))[0]
        program_name = reader.read(program_name_length).decode()
        instance_name_length = struct.unpack(">H", reader.read(2))[0]
        instance_name = reader.read(instance_name_length).decode()
        return Hello(version, cookie, program_name, instance_name)


def test_hello():
    version, cookie, program, instance = "a", "b", "c", "d"
    hello = Hello(version, cookie, program, instance)
    assert(hello.version == version)
    assert(hello.cookie == cookie)
    assert(hello.program_name == program)
    assert(hello.instance_name == instance)
    encoded = hello.encode()
    assert(len(encoded) == 12)
    decoded = Hello.decode(encoded)
    assert(decoded.version == version)
    assert(decoded.cookie == cookie)
    assert(decoded.program_name == program)
    assert(decoded.instance_name == instance)
    assert(hello == decoded)
    assert(str(hello) == str(decoded))


class Ok(object):
    """
    Ok(initial_credits: U32,
        credit_list: Array[(stream_id: U64,
                            stream_name: bytes,
                            point_of_ref: U64)],
        source_list: Array[(source_name: String,
                            source_address: String)])

   """
    def __init__(self, initial_credits, credit_list, source_list):
        self.initial_credits = initial_credits
        self.credit_list = credit_list
        self.source_list = source_list

    def __str__(self):
        return ("Ok(initial_credits={!r}, credit_list={!r}, source_list={!r})"
                .format(self.initial_credits, self.credit_list,
                        self.source_list))

    def __eq__(self, other):
        return (self.initial_credits == other.initial_credits and
                self.credit_list == other.credit_list and
                self.source_list == other.source_list)

    def encode(self):
        packed_credits = []
        for (sid, sn, por) in self.credit_list:
            packed_credits.append(
                struct.pack('>QH{}sQ'.format(len(sn)),
                            sid,
                            len(sn),
                            sn,
                            por))
        packed_sources = []
        for source, addr in self.source_list:
            s = source.encode()
            a = addr.encode()
            packed_sources.append(
                struct.pack('>H{}sH{}s'.format(len(s), len(a)),
                            len(s), s,
                            len(a), a))
        return (struct.pack('>II', self.initial_credits,
                            len(self.credit_list)) +
                b''.join(packed_credits) +
                struct.pack('>I', len(packed_sources)) +
                b''.join(packed_sources))

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        initial_credit = struct.unpack(">I", reader.read(4))[0]
        credit_list_length = struct.unpack(">I", reader.read(4))[0]
        credit_list = []
        for _ in range(credit_list_length):
            stream_id = struct.unpack(">Q", reader.read(8))[0]
            stream_name_length = struct.unpack(">H", reader.read(2))[0]
            stream_name = reader.read(stream_name_length)
            point_of_ref = struct.unpack(">Q", reader.read(8))[0]
            credit_list.append((stream_id,
                                stream_name,
                                point_of_ref))
        source_list_length = struct.unpack('>I', reader.read(4))[0]
        source_list = []
        for _ in range(source_list_length):
            source_length = struct.unpack('>H', reader.read(2))[0]
            source = reader.read(source_length).decode()
            addr_length = struct.unpack('>H', reader.read(2))[0]
            addr = reader.read(addr_length).decode()
            source_list.append((source, addr))
        return Ok(initial_credit, credit_list, source_list)


def test_ok():
    ic, cl = 100, [(1, b"1", 0), (2, b"2", 1)]
    sl = [("source1", "127.0.0.1:7000"), ("source2", "192.168.0.1:5555")]
    ok = Ok(ic, cl, sl)
    assert(ok.initial_credits == ic)
    assert(ok.credit_list == cl)
    assert(ok.source_list == sl)
    encoded = ok.encode()
    assert(len(encoded) == (4 + 4 + len(cl)*(8 + 2 + 1 + 8) +
                            4 + sum((4 + sum(map(len, p)) for p in sl))))
    decoded = Ok.decode(encoded)
    assert(isinstance(decoded, Ok))
    assert(decoded.initial_credits == ic)
    assert(decoded.credit_list == cl)
    assert(decoded == ok)
    assert(str(decoded) == str(ok))


class Error(object):
    """
    Error(msg: String)
    """
    def __init__(self, msg):
        self.message = msg

    def __str__(self):
        return "Error(message={!r})".format(self.message)

    def __eq__(self, other):
        return self.message == other.message

    def encode(self):
        encoded = self.message.encode()
        return struct.pack(">H{}s".format(len(encoded)),
                           len(encoded),
                           encoded)

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        msg_length = struct.unpack(">H", reader.read(2))[0]
        msg = reader.read(msg_length).decode()
        return Error(msg)


def test_error():
    msg = "hello world"
    error = Error(msg)
    assert(error.message == msg)
    encoded = error.encode()
    assert(len(encoded) == len(msg.encode()) + 2)
    decoded = Error.decode(encoded)
    assert(isinstance(decoded, Error))
    assert(decoded.message == msg)
    assert(decoded == error)
    assert(str(decoded) == str(error))


class Notify(object):
    """
    Notify(stream_id: U64, stream_name: bytes, point_of_ref: U64)
    """
    def __init__(self, stream_id, stream_name, point_of_ref=0):
        self.stream_id = stream_id
        self.stream_name = stream_name
        self.point_of_ref = point_of_ref

    def __str__(self):
        return ("Notify(stream_id={!r}, stream_name={!r}, point_of_ref={!r})"
                .format(self.stream_id, self.stream_name, self.point_of_ref))

    def __eq__(self, other):
        return (self.stream_id == other.stream_id and
                self.stream_name == other.stream_name and
                self.point_of_ref == other.point_of_ref)

    def encode(self):
        return struct.pack(">QH{}sQ".format(len(self.stream_name)),
                           self.stream_id,
                           len(self.stream_name),
                           self.stream_name,
                           self.point_of_ref)

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        stream_id = struct.unpack(">Q", reader.read(8))[0]
        stream_name_length = struct.unpack(">H", reader.read(2))[0]
        stream_name = reader.read(stream_name_length)
        point_of_ref = struct.unpack(">Q", reader.read(8))[0]
        return Notify(stream_id, stream_name, point_of_ref)


def test_notify():
    sid, sn, por = 0, b"0", 1
    notify = Notify(sid, sn, por)
    assert(notify.stream_id == sid)
    assert(notify.stream_name == sn)
    assert(notify.point_of_ref == por)
    encoded = notify.encode()
    assert(len(encoded) == 8 + 2 + 1 + 8)
    decoded = Notify.decode(encoded)
    assert(isinstance(decoded, Notify))
    assert(decoded.stream_id == sid)
    assert(decoded.stream_name == sn)
    assert(decoded.point_of_ref == por)
    assert(decoded == notify)
    assert(str(decoded) == str(notify))


class NotifyAck(object):
    """
    NotifyAck(notify_success: Bool, stream_id: U64, point_of_ref: U64)
    """
    def __init__(self, notify_success, stream_id, point_of_ref):
        self.notify_success = notify_success
        self.stream_id = stream_id
        self.point_of_ref = point_of_ref

    def __str__(self):
        return ("NotifyAck(notify_success={!r}, stream_id={!r}, point_of_ref={!r})"
                .format(self.notify_success, self.stream_id,
                        self.point_of_ref))

    def __eq__(self, other):
        return (self.notify_success == other.notify_success and
                self.stream_id == other.stream_id and
                self.point_of_ref == other.point_of_ref)

    def encode(self):
        return struct.pack('>?QQ',
                           self.notify_success,
                           self.stream_id,
                           self.point_of_ref)

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        notify_success = struct.unpack(">?", reader.read(1))[0]
        stream_id = struct.unpack(">Q", reader.read(8))[0]
        point_of_ref = struct.unpack(">Q", reader.read(8))[0]
        return NotifyAck(notify_success, stream_id, point_of_ref)


def test_notify_ack():
    suc, sid, por = False, 0, 12
    notify_ack = NotifyAck(suc, sid, por)
    assert(notify_ack.notify_success == suc)
    assert(notify_ack.stream_id == sid)
    assert(notify_ack.point_of_ref == por)
    encoded = notify_ack.encode()
    assert(len(encoded) == 1 + 8 + 8)
    decoded = NotifyAck.decode(encoded)
    assert(isinstance(decoded, NotifyAck))
    assert(decoded.notify_success == suc)
    assert(decoded.stream_id == sid)
    assert(decoded.point_of_ref == por)
    assert(decoded == notify_ack)
    assert(str(decoded) == str(notify_ack))


class Message(object):
    """
    Message(stream_id: int, message_id: int,
            event_time: int, key: (bytes | None),
            message: (bytes | None))
    """

    def __init__(self, stream_id, message_id, event_time,
                 key=None, message=None):
        self.stream_id = stream_id
        self.message_id = message_id
        self.event_time = event_time
        if key is None or isinstance(key, bytes):
            self.key = key
        else:
            raise TypeError("Parameter key must be either None or bytes")
        if message is None or isinstance(message, bytes):
            self.message = message
        else:
            raise TypeError("Parameter message must be either None or bytes")

    def __str__(self):
        return ("Message(stream_id={!r}, message_id={!r}, event_time"
                "={!r}, key={!r}, message={!r})".format(
                    self.stream_id,
                    self.message_id,
                    self.event_time,
                    self.key,
                    self.message))

    def __eq__(self, other):
        return (self.stream_id == other.stream_id and
                self.message_id == other.message_id and
                self.event_time == other.event_time and
                self.key == other.key and
                self.message == other.message)

    def encode(self):
        sid = struct.pack('>Q', self.stream_id)
        messageid = struct.pack('>Q', self.message_id)
        event_time = struct.pack('>q', self.event_time)
        if self.key is None:
            k = b''
        else:
            k = self.key
        key = struct.pack('>H{}s'.format(len(k)), len(k), k)
        msg = self.message if self.message else b''
        return b''.join((sid, messageid, event_time, key, msg))

    @classmethod
    def decode(cls, bs):
        reader = StringIO(bs)
        stream_id = struct.unpack('>Q', reader.read(8))[0]
        message_id = struct.unpack('>Q', reader.read(8))[0]
        event_time = struct.unpack('>q', reader.read(8))[0]
        key_length = struct.unpack('>H', reader.read(2))[0]
        if key_length > 0:
            key = reader.read(key_length)
        else:
            key = None
        message = reader.read()
        if message == b'':
            message = None
        return cls(stream_id, message_id, event_time, key, message)


def test_message():
    from itertools import chain, product
    from functools import reduce
    import pytest
    M = Message
    stream_id = 123
    message_id = 456
    event_time = 0
    key = 'key'.encode()
    message = 'hello world'.encode()

    msg = Message(stream_id, message_id, event_time, key, message)
    assert(msg.stream_id == stream_id)
    assert(msg.message_id == message_id)
    assert(msg.event_time == event_time)
    assert(msg.key == key)
    assert(msg.message == message)

    encoded = msg.encode()
    assert(len(encoded) == (
        8 +
        8 +
        8 +
        ((2 + len(key)) if msg.key else 0) +
        (len(message) if msg.message else 0)))

    decoded = Message.decode(encoded)
    assert(isinstance(decoded, Message))
    assert(decoded.stream_id == msg.stream_id)
    assert(decoded.message_id == msg.message_id)
    assert(decoded.event_time == msg.event_time)
    assert(decoded.key == msg.key)
    assert(decoded.message == msg.message)
    assert(decoded == msg)
    assert(str(decoded) == str(msg))
    # Test that all messages frame encode/decode correctly
    _test_frame_encode_decode(msg)

    partial_msg = Message(stream_id, message_id, event_time)
    assert(partial_msg.stream_id == stream_id)
    assert(partial_msg.message_id == message_id)
    assert(partial_msg.event_time == event_time)
    assert(partial_msg.key == None)
    assert(partial_msg.message == None)

    partial_encoded = partial_msg.encode()
    assert(len(partial_encoded) == (
        8 +
        8 +
        8 +
        (2 + 0) +
        0))

    partial_decoded = Message.decode(partial_encoded)
    assert(isinstance(decoded, Message))
    assert(partial_decoded.stream_id == partial_msg.stream_id)
    assert(partial_decoded.message_id == partial_msg.message_id)
    assert(partial_decoded.event_time == partial_msg.event_time)
    assert(partial_decoded.key == partial_msg.key)
    assert(partial_decoded.message == partial_msg.message)
    assert(partial_decoded == partial_msg)
    assert(str(partial_decoded) == str(partial_msg))
    # Test that all messages frame encode/decode correctly
    _test_frame_encode_decode(partial_msg)


class EosMessage(object):
    """
    EosMessage(stream_id: int)
    """
    def __init__(self, stream_id):
        self.stream_id = stream_id

    def __str__(self):
        return ("EosMessage(stream_id={!r})".format(self.stream_id))

    def __eq__(self, other):
        return (self.stream_id == other.stream_id)

    def encode(self):
        return struct.pack('>Q', self.stream_id)

    @classmethod
    def decode(cls, bs):
        reader = StringIO(bs)
        stream_id = struct.unpack('>Q', reader.read(8))[0]
        return cls(stream_id)

def test_eos_message():
    from itertools import chain, product
    from functools import reduce
    import pytest
    stream_id = 0x2a2b2c3d2a2b2c3d

    msg = EosMessage(stream_id)
    assert(msg.stream_id == stream_id)
    encoded = msg.encode()
    print("len(ENCODED) = {}".format(len(encoded)))
    print("ENCODED = {!r}<--.".format(encoded))
    assert(len(encoded) == (8))

    decoded = EosMessage.decode(encoded)
    assert(isinstance(decoded, EosMessage))
    assert(decoded.stream_id == msg.stream_id)

class Ack(object):
    """
    Ack(credits: U32, acks: Array[(stream_id: U64, point_of_ref: U64)]
    """
    def __init__(self, credits, acks):
        self.credits = credits
        self.acks = acks

    def __str__(self):
        return "Ack(credits={!r}, acks={!r})".format(self.credits, self.acks)

    def __eq__(self, other):
        return (self.credits == other.credits and
                self.acks == other.acks)

    def encode(self):
        return (struct.pack('>II', self.credits, len(self.acks)) +
                b''.join((
                    struct.pack('>QQ', sid, por)
                    for sid, por in self.acks)))

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        credits = struct.unpack(">I", reader.read(4))[0]
        acks_length = struct.unpack(">I", reader.read(4))[0]
        acks = []
        for _ in range(acks_length):
            stream_id = struct.unpack(">Q", reader.read(8))[0]
            point_of_ref = struct.unpack(">Q", reader.read(8))[0]
            acks.append((stream_id, point_of_ref))
        return Ack(credits, acks)


def test_ack():
    c, acks = 100, [(1, 12), (2, 25), (5, 501)]
    ack = Ack(c, acks)
    assert(ack.credits == c)
    assert(ack.acks == acks)
    encoded = ack.encode()
    assert(len(encoded) == 4 + 4 + len(acks)*(8+8))
    decoded = Ack.decode(encoded)
    assert(isinstance(decoded, Ack))
    assert(decoded.credits == c)
    assert(decoded.acks == acks)
    assert(decoded == ack)
    assert(str(decoded) == str(ack))


class Restart(object):
    """
    Restart(address: String)
    """
    def __init__(self, address=None):
        self.address = address

    def __str__(self):
        return "Restart({!r})".format(self.address)

    def __eq__(self, other):
        return (other.address == self.address)

    def encode(self):
        if self.address is not None:
            b_addr = self.address.encode()
            return struct.pack('>I{}s'.format(len(b_addr)),
                               len(b_addr),
                               b_addr)
        else:
            return struct.pack('>I', 0)

    @staticmethod
    def decode(bs):
        addr = None
        if len(bs) > 0:
            reader = StringIO(bs)
            a_length = struct.unpack('>I', reader.read(4))[0]
            if a_length > 0:
                addr = reader.read(a_length).decode()
        return Restart(addr)


def test_restart():
    addr = '127.0.0.1:5555'
    r = Restart(addr)
    encoded = r.encode()
    assert(len(encoded) == len(addr.encode()) + 4)
    decoded = Restart.decode(encoded)
    assert(isinstance(decoded, Restart))
    assert(decoded == r)
    assert(str(decoded) == str(r))


class Frame(object):
    _FRAME_TYPE_TUPLES = [(0, Hello),
                          (1, Ok),
                          (2, Error),
                          (3, Notify),
                          (4, NotifyAck),
                          (5, Message),
                          (6, Ack),
                          (7, Restart),
                          (8, EosMessage)]
    _FRAME_TYPE_MAP = dict([(v, t) for v, t in _FRAME_TYPE_TUPLES] +
                           [(t, v) for v, t in _FRAME_TYPE_TUPLES])

    @classmethod
    def encode(cls, msg):
        frame_tag = cls._FRAME_TYPE_MAP[type(msg)]
        data = msg.encode()
        return struct.pack('>IB', len(data)+1, frame_tag) + data

    @classmethod
    def decode(cls, bs): # bs does not include frame length header
        frame_tag = struct.unpack('>B', bs[0:1])[0]
        return cls._FRAME_TYPE_MAP[frame_tag].decode(bs[1:])

    @staticmethod
    def read_header(bs):
        return struct.unpack('>I', bs[:4])[0]


def _test_frame_encode_decode(msg):
    framed = Frame.encode(msg)
    decoded = Frame.decode(framed[4:])
    assert(decoded == msg)

def test_frame():
    assert(Frame.read_header(struct.pack('>I', 50)) == 50)
    msgs = []
    msgs.append(Hello("version", "cookie", "program_name", "instance_name"))
    msgs.append(Ok(100, [(1,b"",1), (2, b"2", 2)], [("s1", "1.1.1.1:1234")]))
    msgs.append(Error("this is an error message"))
    msgs.append(Notify(123, b"stream123", 1001))
    msgs.append(NotifyAck(False, 123, 1001))
    # Message framing is tested in the test_message test
    msgs.append(Ack(1000, [(123, 999), (300, 200)]))
    msgs.append(Restart('127.0.0.1:5555'))

    for msg in msgs:
        _test_frame_encode_decode(msg)

####
#### 2PC
####

class ListUncommitted(object):
    """
    ListUncommitted(rtag: U64)
    """
    def __init__(self, rtag):
        self.rtag = rtag

    def __str__(self):
        return "ListUncommitted(rtag={!r})".format(self.rtag)

    def __eq__(self, other):
        return (self.rtag == other.rtag)

    def encode(self):
        return (struct.pack('>Q', self.rtag))

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        rtag = struct.unpack(">Q", reader.read(8))[0]
        return ListUncommitted(rtag)

class ReplyUncommitted(object):
    """
    ReplyUncommitted(rtag: U64, txn_ids: Array[(txn_id: String])
    """
    def __init__(self, rtag, txn_ids):
        self.rtag = rtag
        self.txn_ids = txn_ids

    def __str__(self):
        return "ReplyUncommitted(rtag={!r}, txn_ids={!r})".format(self.rtag, self.txn_ids)

    def __eq__(self, other):
        return (self.rtag == other.rtag and
                self.txn_ids == other.txn_ids)

    def encode(self):
        return (struct.pack('>QI', self.rtag, len(self.txn_ids)) +
                b''.join((
                    struct.pack('>H{}s'.format(len(txn_id)),
                        len(txn_id), txn_id.encode("utf-8"))
                    for txn_id in self.txn_ids)))

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        credits = struct.unpack(">I", reader.read(4))[0]
        acks_length = struct.unpack(">I", reader.read(4))[0]
        acks = []
        for _ in range(acks_length):
            stream_id = struct.unpack(">Q", reader.read(8))[0]
            point_of_ref = struct.unpack(">Q", reader.read(8))[0]
            acks.append((stream_id, point_of_ref))
        return Ack(credits, acks)

def encode_phase2r(txn_id, commit):
    if commit:
        commit_c = b'\01'
    else:
        commit_c = b'\00'
    return struct.pack(">H{}sc".format(len(txn_id)),
                       len(txn_id),
                       txn_id,
                       commit_c)

def decode_phase2r(bs):
    reader = StringIO(bs)
    length = struct.unpack(">H", reader.read(2))[0]
    txn_id = reader.read(length).decode()
    commit_c = reader.read(1)
    if commit_c == b'\01':
        commit = True
    else:
        commit = False
    return (txn_id, commit)

class TwoPCPhase1(object):
    """
    TwoPCPhase1(txn_id: String,
      where_list: [(stream_id: U64, start_por: U64, end_por: U64)])
    """
    def __init__(self, txn_id, where_list):
        self.txn_id = txn_id
        self.where_list = where_list

    def __str__(self):
        return "TwoPCPhase1(txn_id={!r},where_list={!r})".format(self.txn_id, self.where_list)

    def __eq__(self, other):
        return (self.txn_id == other.txn_id and
                self.where_list == other.where_list)

    def encode(self):
        return (struct.pack(">H{}sI".format(len(txn_id)),
                            len(txn_id),
                            txn_id,
                            len(where_list)) +
                    b''.join((
                        struct.pack('>QQQ',
                            stream_id, start_por, end_por)
                        for (stream_id, start_por, end_por) in self.where_list)))

    @staticmethod
    def decode(bs):
        reader = StringIO(bs)
        length = struct.unpack(">H", reader.read(2))[0]
        txn_id = reader.read(length).decode()
        where_list = []
        length = struct.unpack(">I", reader.read(4))[0]
        for i in range(0, length):
            stream_id = struct.unpack(">Q", reader.read(8))[0]
            start_por = struct.unpack(">Q", reader.read(8))[0]
            end_por = struct.unpack(">Q", reader.read(8))[0]
            where_list.append((stream_id, start_por, end_por))
        return TwoPCPhase1(txn_id, where_list)

class TwoPCReply(object):
    """
    TwoPCReply(txn_id: String, commit: Boolean)
    """
    def __init__(self, txn_id, commit):
        self.txn_id = txn_id
        self.commit = commit

    def __str__(self):
        return "TwoPCReply(txn_id={!r},commit={!r})".format(self.txn_id, self.commit)

    def __eq__(self, other):
        return (self.txn_id == other.txn_id and
                self.commit == other.commit)

    def encode(self):
        return encode_phase2r(self.txn_id, self.commit)

    @staticmethod
    def decode(bs):
        (txn_id, commit) = decode_phase2r(bs)
        return TwoPCReply(txn_id, commit)

class TwoPCPhase2(object):
    """
    TwoPCPhase2(txn_id: String, commit: Boolean)
    """
    def __init__(self, txn_id, commit):
        self.txn_id = txn_id
        self.commit = commit

    def __str__(self):
        return "TwoPCPhase2(txn_id={!r},commit={!r})".format(self.txn_id, self.commit)

    def __eq__(self, other):
        return (self.txn_id == other.txn_id and
                self.commit == other.commit)

    def encode(self):
        return encode_phase2r(self.txn_id, self.commit)

    @staticmethod
    def decode(bs):
        (txn_id, commit) = decode_phase2r(bs)
        return TwoPCPhase2(txn_id, commit)

class TwoPCFrame(object):
    _FRAME_TYPE_TUPLES = [(201, ListUncommitted) ,
                          (202, ReplyUncommitted) ,
                          (203, TwoPCPhase1),
                          (204, TwoPCReply),
                          (205, TwoPCPhase2)
                          ]
    _FRAME_TYPE_MAP = dict([(v, t) for v, t in _FRAME_TYPE_TUPLES] +
                           [(t, v) for v, t in _FRAME_TYPE_TUPLES])

    @classmethod
    def encode(cls, msg):
        frame_tag = cls._FRAME_TYPE_MAP[type(msg)]
        data = msg.encode()
        # Don't add length for this inner message type
        return struct.pack('>B', frame_tag) + data

    @classmethod
    def decode(cls, bs): # bs does not include frame length header
        frame_tag = struct.unpack('>B', bs[0:1])[0]
        return cls._FRAME_TYPE_MAP[frame_tag].decode(bs[1:])

    @staticmethod
    def read_header(bs):
        return struct.unpack('>I', bs[:4])[0]


def _test_twopcframe_encode_decode(msg):
    framed = TwoPCFrame.encode(msg)
    decoded = TwoPCFrame.decode(framed[4:])
    assert(decoded == msg)

def test_frame():
    assert(Frame.read_header(struct.pack('>I', 50)) == 50)
    msgs = []
    #msgs.append(ListUncommitted(77))
    #msgs.append(ReplyUncommitted(...))
    #msgs.append(TwoPCPhase1(...))
    #msgs.append(TwoPCReply(...))
    #msgs.append(TwoPCPhase2(...))
    #msgs.append(TwoPCPhase1(...))

    for msg in msgs:
        _test_frame_encode_decode(msg)
