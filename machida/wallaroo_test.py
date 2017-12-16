import pickle
import struct
import wallaroo


#
# Test computation
#


@wallaroo.computation(name="My Computation")
def my_computation(data):
    return data


def test_my_computation():
    assert(my_computation.name() == "My Computation")
    assert(my_computation.compute("abcd") == "abcd")


def test_serialization():
    serialized = pickle.dumps(my_computation)
    deserialized = pickle.loads(serialized)
    assert(deserialized.name() == "My Computation")
    assert(deserialized.compute("abcd") == "abcd")


#
# Test computation_multi
#


@wallaroo.computation_multi(name="My Computation Multi")
def my_computation_multi(data):
    return data.split(" ")


def test_my_computation_multi():
    assert(my_computation_multi.name() == "My Computation Multi")
    assert(my_computation_multi.compute_multi("hello world dear friend") ==
           ["hello", "world", "dear", "friend"])


def test_my_computation_multi_serialization():
    serialized = pickle.dumps(my_computation_multi)
    deserialized = pickle.loads(serialized)
    assert(deserialized.name() == "My Computation Multi")
    assert(deserialized.compute_multi("hello world dear friend") ==
           ["hello", "world", "dear", "friend"])


#
# Test state computation
#


@wallaroo.state_computation(name="My State Computation")
def my_state_computation(data, state):
    return ((data, state), True)


def test_my_state_computation():
    assert(my_state_computation.name() == "My State Computation")
    assert(my_state_computation.compute("hello", "world") ==
           (("hello", "world"), True))


def test_my_state_computation_serializatin():
    serialized = pickle.dumps(my_state_computation)
    deserialized = pickle.loads(serialized)
    assert(deserialized.name() == "My State Computation")
    assert(deserialized.compute("hello", "world") ==
           (("hello", "world"), True))


#
# Test state computation multi
#


@wallaroo.state_computation_multi(name="My State Computation Multi")
def my_state_computation_multi(data, state):
    return ((data.split(" "), state), True)


def test_my_state_computation_multi():
    assert(my_state_computation_multi.name() == "My State Computation Multi")
    assert(my_state_computation_multi.compute_multi("hello world", 1) ==
           ((["hello", "world"], 1), True))


def test_my_state_computation_multi_serialization():
    serialized = pickle.dumps(my_state_computation_multi)
    deserialized = pickle.loads(serialized)
    assert(deserialized.name() == "My State Computation Multi")
    assert(deserialized.compute_multi("hello world", 1) ==
           ((["hello", "world"], 1), True))


#
# Test state
#


class MyState(object):
    def __init__(self):
        self.x = 0
        self.y = 0

    def add(self):
        self.x += 1

    def build(self):
        self.y += 1


def test_MyState():
    mystate = MyState()
    assert(hasattr(mystate, 'add'))
    assert(hasattr(mystate, 'build'))
    assert(mystate.x == 0)
    assert(mystate.y == 0)
    mystate.add()
    mystate.build()
    assert(mystate.x == 1)
    assert(mystate.y == 1)
    mystate = MyState()
    assert(mystate.x == 0)
    assert(mystate.y == 0)



def test_MyState_serialization():
    # 1. test serialization of the object class
    serialized = pickle.dumps(MyState)
    deserialized = pickle.loads(serialized)
    # 2. test object created from deserialized class behaves as expected
    mystate = deserialized()
    assert(mystate.x == 0)
    assert(mystate.y == 0)
    mystate.add()
    mystate.build()
    assert(mystate.x == 1)
    assert(mystate.y == 1)
    # 3. test serialization of the object instance
    serialized2 = pickle.dumps(mystate)
    deserialized2 = pickle.loads(serialized2)
    assert(deserialized2.x == 1)
    assert(deserialized2.y == 1)
    # 4. test that the original instance and deserialized one are different objects
    assert(deserialized2 != mystate)
    mystate.add()
    deserialized2.build()
    assert(mystate.x == 2)
    assert(mystate.y == 1)
    assert(deserialized2.x == 1)
    assert(deserialized2.y == 2)


#
# Test partition serialization
#


@wallaroo.partition
def my_partition(data):
    return data[0]


def test_my_partition():
    assert(my_partition.partition('abcde') == 'a')
    assert(my_partition.partition('d') == 'd')


def test_my_partition_serialization():
    serialized = pickle.dumps(my_partition)
    deserialized = pickle.loads(serialized)
    assert(deserialized.partition('abcde') == 'a')


#
# Test decoder
#


@wallaroo.decoder(header_length=4, length_fmt='>I')
def my_decoder(data):
    return 'decoded: {!r}'.format(data)


def test_my_decoder():
    assert(my_decoder.header_length() == 4)
    assert(my_decoder.payload_length(struct.pack('>I', 10)) == 10)
    assert(my_decoder.decode('hello') == "decoded: 'hello'")


def test_my_decoder_serialization():
    serialized = pickle.dumps(my_decoder)
    deserialized = pickle.loads(serialized)
    assert(deserialized.header_length() == 4)
    assert(deserialized.payload_length(struct.pack('>I', 10)) == 10)
    assert(deserialized.decode('hello') == "decoded: 'hello'")


#
# Test encoder
#


@wallaroo.encoder
def my_encoder(data):
    return 'encoded: {!r}'.format(data)


def test_my_encoder():
    assert(my_encoder.encode('hello') == "encoded: 'hello'")


def test_my_encoder_serialization():
    serialized = pickle.dumps(my_encoder)
    deserialized = pickle.loads(serialized)
    assert(deserialized.encode('hello') == "encoded: 'hello'")
