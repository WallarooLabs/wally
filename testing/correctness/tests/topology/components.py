from pickle import dumps, loads

def attach_to_module(func, identifier):
    # Do some scope mangling to create a uniquely named class based on
    # the decorated function's name and place it in the wallaroo module's
    # namespace so that pickle can find it.

    func.__name__ = identifier
    globals()[identifier] = func
    return globals()[identifier]


class Message(object):
    def __init__(self, value, key=None, tags=None, states=None):
        self.value = value
        self.key = str(key)
        self.tags = tags if tags else []
        self.states = states if states else []

    def new_from_key(self, key):
        return Message(self.value, "{}.{}".format(self.key, key),
                       list(self.tags), list(self.states))

    def tag(self, tag, state=None, key=None):
        self.tags.append(tag)
        self.states.append(state)

    def encode(self):
        return dumps(self)

    def __str__(self):
        return ("{{key: {key}, value: {value}, tags: {tags}, "
                " states: {states}}}".format(
                    key=self.key,
                    value=self.value,
                    tags=self.tags,
                    states=self.states))

    @staticmethod
    def decode(bs):
        return loads(bs)


class State(object):
    _partitioned = False
    def __init__(self):
        self._a = None
        self._b = None
        self._initialized = False

    def update(self, data):
        if self._initialized:
            if self._partitioned:
                assert(self._b[0] == data.key) # check key compatibility
        else:
            self._initialized = True

        # state update:
        self._a = self._b
        self._b = (data.key, data.value)

    def __str__(self):
        return ("{{_a: {a}, _b: {b}, _initialized: "
                "{initialized}}}".format(
                    a = self._a,
                    b = self._b,
                    initialized = self._initialized))

    def clone(self):
        return (self._a, self._b)


class PartitionedState(State):
    _partitioned = True


def partition(msg):
    return msg.key


# Computations
def Tag(identifier, flow_mod=None):
    identifier = "tag_{}".format(identifier)
    def tag(data, state=None):
        print("{}({})".format(identifier, data))
        data.tag(identifier)
        return data
    # apply flow_modifier
    if flow_mod:
        tag = flow_mod(tag)
    return attach_to_module(tag, identifier)


def TagState(identifier, flow_mod=None):
    identifier = "tagstate_{}".format(identifier)
    def tagstate(data, state):
        print("{}({}, {})".format(identifier, data, state))
        state.update(data)
        # Really important to be sure we use `state.clone` and not `state`
        # in the data.tag function! State is mutable and is gonna be a mess
        # if we put it in there.
        data.tag(identifier, state.clone())
        return(data, True)
    # apply flow_modifier
    if flow_mod:
        tagstate = flow_mod(tagstate)
    return attach_to_module(tagstate, identifier)



# Flow modifiers
def OneToN(num):
    identifier = "oneton_{}".format(num)
    def oneton(func):
        def oneton_wrapped(data, state=None):
            data = func(data, state)
            print("{}({})".format(identifier, data))
            if data and state:
                return [data[0].new_from_key(x) for x in range(num)]
            elif data:
                return [data.new_from_key(x) for x in range(num)]
            return None
        return oneton_wrapped
    return attach_to_module(oneton, identifier)


def FilterBy(identifier, by=()):
    """
    Use a function to determine whether to drop the message.
    Drop message if by(message) returns True.
    Default: no drop (same as Tag)
    if `by` is a tuple, use a lazy modulo test to filter every position in
    the tuple. e.g. if `by=(3,4)`, drop every case where
        `data.value % 3 == 0 or data.value % 4 == 0`
    """
    identifier = "filterby_{}".format(identifier)
    def filterby(data):
        def filterby_wrapped(data, state=None):
            if isinstance(by, (tuple,list)):
                if any((data.value % d == 0) for d in by):
                    print("{}({})".format(identifier, data))
                    return None
            else:
                if by(data):
                    print("{}({})".format(identifier, data))
                    return None
            print("filterby_pass({})".format(data))
            return data
        return filterby_wrapped
    return attach_to_module(filterby, identifier)


def test_components():
    m = Message(1,1)
    s = State()
    t1 = Tag(1)
    ts1 = TagState(1)
    t1(m)
    ts1(m,s)
    assert(m.value == 1)
    assert(m.key == "1")
    assert(m.tags == ['tag_1', 'tagstate_1'])
    assert(m.states == [None, (None, ("1", 1))])


def test_flow_mods():
    m = Message(1,1)
    s = State()
    # one to 2
    t1 = Tag(1, OneToN(2))
    t2 = Tag(2, FilterBy('filter', lambda d: not d.key.endswith(".0")))
    ts1 = TagState(1, OneToN(2))
    ts2 = TagState(2, FilterBy('filter', lambda d: not d.key.endswith(".0")))
    res_t1 = t1(m)
    res_t2 = [t2(v) for v in res_t1]
    assert(res_t2[1] is None)
    assert(res_t2[0].key == '1.0')

    res_ts1 = ts1(res_t2[0], s)
    res_ts2 = [ts2(v,s) for v in res_ts1]
    assert(res_ts2[1] is None)
    assert(res_ts2[0].key == '1.0.0')
    assert(len(res_t1) == 2)
    assert(len(res_ts1) == 2)
    assert(res_ts2[0].value == 1)
    assert(res_ts2[0].tags == ['tag_1', 'tagstate_1'])
    assert(res_ts2[0].states == [None, (None, ('1.0', 1))])


def test_serialisation():
    import wallaroo

    m1 = Message(1,1)
    m2 = Message(1,1)
    s1 = State()
    s2 = State()
    s3 = State()
    s4 = State()
    t1 = Tag(1)
    t2 = Tag(2, OneToN(2))
    ts1 = TagState(1)
    ts2 = TagState(2, OneToN(2))
    wt1 = wallaroo.computation("tag1")(t1)
    wt2 = wallaroo.computation("tag2_to2")(t2)
    wts1 = wallaroo.state_computation("tagstate1")(ts1)
    wts2 = wallaroo.state_computation("tagstate2_to2")(ts2)
    res = wt1.compute(m1)  # returns data
    res = wts1.compute(res, s1)  # returns (data, flag)
    res = wt2.compute(res[0])  # returns [data]
    res = wts2.compute(res[0], s2)  # returns ([data], flag)
    r1 = res[0]
    print('r1', str(r1))
    assert(r1.value == 1)
    assert(r1.key == "1.0.0")
    assert(r1.tags == ['tag_1', 'tagstate_1', 'tag_2', 'tagstate_2'])
    assert(r1.states == [None, (None, ("1", 1)), None, (None, ('1.0', 1))])

    # serialise, deserialse, then run again
    ds_wt1 = loads(dumps(wt1))
    ds_wt2 = loads(dumps(wt2))
    ds_wts1 = loads(dumps(wts1))
    ds_wts2 = loads(dumps(wts2))
    res = ds_wt1.compute(m2)  # returns data
    res = ds_wts1.compute(res, s3)  # returns (data, flag)
    res = ds_wt2.compute(res[0])  # returns [data]
    res = ds_wts2.compute(res[0], s4)  # returns ([data], flag)
    r2 = res[0]
    assert(r2.value == 1)
    assert(r2.key == "1.0.0")
    assert(r2.tags == ['tag_1', 'tagstate_1', 'tag_2', 'tagstate_2'])
    assert(r2.states == [None, (None, ("1", 1)), None, (None, ('1.0', 1))])


def test_state():
    s = State()
    sp = PartitionedState()
    m1 = Message(1,1)
    m2 = Message(2,2)
    s.update(m1)
    s.update(m2)
    sp.update(m1)
    sp.update(m1)
    try:
        sp.update(m2)
    except Exception as err:
        assert(isinstance(err, AssertionError))


def test_attach_to_module():
    identifier = 'my_function'
    def my_function():
        return 'my function result'
    assert(globals().get(identifier) is None)
    assert(my_function.__name__ == identifier)
    my_function = attach_to_module(my_function, identifier)
    assert(globals().get(identifier) is not None)
    assert(my_function.__name__ == identifier)
