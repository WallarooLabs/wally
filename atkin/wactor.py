

def join_longs(left, right):
    r = left << 64
    r += right
    return r


def split_longs(u128):
    l = u128 >> 64
    r = u128 - (l << 64)
    return (l, r)


class WActor:
    def __init__(self):
        self._call_log = []

    def _clear_call_log(self):
        self._call_log = []

    def _get_call_log(self):
        cl = self._call_log
        self._clear_call_log()
        return cl

    def send_to(self, actor_id, msg):
        self._call_log.append(("send_to", (split_longs(actor_id), msg)))

    def send_to_role(self, role, msg):
        self._call_log.append(("send_to_role", (role, msg)))

    def send_to_sink(self, sink_id, msg):
        self._call_log.append(("send_to_sink", (sink_id, msg)))

    def register_as_role(self, role):
        self._call_log.append(("register_as_role", (role)))

    def receive_wrapper(self, sender_id_left, sender_id_right, msg):
        self.receive(join_longs(sender_id_left, sender_id_right), msg)
        return self._get_call_log()

    def process_wrapper(self, data=None):
        self.process(data)
        return self._get_call_log()

    def setup_wrapper(self, actor_id_left, actor_id_right):
        self.actor_id = join_longs(actor_id_left, actor_id_right)
        self.setup()
        return self._get_call_log()


class Source:
    def kind(self):
        return "external"


class SimulatedSource:
    def kind(self):
        return "simulated"


class ActorSystem:
    def __init__(self, name):
        self.name = name
        self.actors = []
        self.sources = []
        self.sinks = []

    def add_actor(self, actor):
        self.actors.append(actor)

    def add_source(self, source):
        self.sources.append(source)

    def add_sink(self, sink):
        self.sinks.append(sink)

    def add_simulated_source(self):
        self.sources.append(SimulatedSource())
