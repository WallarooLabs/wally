import struct
import wactor

EXECUTION_FEED = 0
L1_FEED = 1
L2_FEED = 2


def create_actor_system(args):
    actor_system = wactor.ActorSystem("Exchange Matching Engine")
    actor_system.add_source(Decoder())
    actor_system.add_actor(Dispatch())
    actor_system.add_actor(Book("Buy"))
    actor_system.add_actor(Book("Sell"))
    actor_system.add_actor(Uncrosser())
    actor_system.add_sink(ExecutionEncoder())
    actor_system.add_sink(QuoteEncoder(True))
    actor_system.add_sink(QuoteEncoder())
    return actor_system


class Order(object):
    """An order coming from a FIX engine"""
    def __init__(self, is_buy, price, qty):
        if is_buy:
            self.side = "Buy"
        else:
            self.side = "Sell"
        self.price = price
        self.qty = qty


class Uncross(object):
    """A signal to uncross the top of the book up to a certain price"""
    def __init__(self, price, qty, send_trades):
        self.price = price
        self.qty = qty
        self.send_trades = send_trades


class Execution(object):
    """An execution of a trade"""
    def __init__(self, price, qty):
        self.price = price
        self.qty = qty


class FeedMsg(object):
    """Level-1 Feed Message"""
    def __init__(self, kind, price, qty):
        self.kind = kind
        self.price = price
        self.qty = qty


class UpdateTopOfBook(object):
    """Level-1 Feed Message"""
    def __init__(self, kind, price, qty, executed):
        self.kind = kind
        self.price = price
        self.qty = qty
        self.executed = executed


class Decoder(wactor.Source):
    """Decode incoming binary orders"""
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">L", bs)[0]

    def decode(self, bs):
        is_buy, price, quantity = struct.unpack('>?fL', bs)
        return Order(is_buy, price, quanity)


class Dispatch(wactor.WActor):
    """Dispatched incoming orders to the right place"""
    def setup(self):
        self.register_as_role("ingress")

    def receive(self, sender_id, msg):
        raise "Dispatch should not receive internal messages"

    def process(self, order):
        self.send_to_role(order.side, order)


class Uncrosser(wactor.WActor):
    """Subscribes to the l1 feed and uncrosses the book when it is crossed"""

    def __init__(self):
        super(Uncrosser, self).__init__()
        self.best = {"BID": None, "ASK": None}

    def setup(self):
        self.register_as_role("uncrosser")

    def receive(self, sender_id, msg):
        if type(msg) is UpdateTopOfBook:
            if msg.kind in ["BID", "ASK"]:
                self.best[msg.kind] = msg.price
                if ((not msg.executed) and self.best["BID"] is not None and
                        self.best["ASK"] is not None and self.best["BID"] >
                        self.best["ASK"]):
                    self.send_to_role(
                            "Buy",
                            Uncross(self.best["ASK"], msg.qty,
                                    msg.kind != "BID"))
                    self.send_to_role(
                            "Sell",
                            Uncross(self.best["BID"], msg.qty,
                                    msg.kind != "ASK"))

    def process(self, data):
        raise "Uncrosser should not receive external messages"


class Book(wactor.WActor):
    """Manages the order book"""
    def __init__(self, side):
        super(Book, self).__init__()
        self.side = side
        self.resting = []

    def compare(self, a, b):
        if self.side == "Buy":
            return a < b
        else:
            return a > b

    def setup(self):
        self.register_as_role(self.side)

    def send_execution(self, price, qty):
        """Send execution to the execution and L1 feeds"""
        self.send_to_sink(0, Execution(price, qty))
        self.send_to_sink(1, FeedMsg("TRADE", price, qty))

    def quote(self, order, feed, executed):
        if self.side == "Buy":
            m = FeedMsg("BID", order.price, order.qty)
        else:
            m = FeedMsg("ASK", order.price, order.qty)
        if feed == L1_FEED:
            self.send_to_role("uncrosser",
                              UpdateTopOfBook(m.kind, m.price, m.qty, executed)
                              )
        self.send_to_sink(feed, m)

    def receive(self, sender_id, msg):
        if type(msg) is Order:
            insert_index = 0
            for i in range(len(self.resting)):
                if self.compare(msg.price, self.resting[i].price):
                    insert_index = i
            self.resting.insert(insert_index, msg)
            self.quote(msg, L2_FEED, False)
            if insert_index == 0:
                self.quote(msg, L1_FEED, False)
        if type(msg) is Uncross:
            start_index = 0
            remaining_qty = msg.qty
            for i in range(len(self.resting)):
                if not self.compare(self.resting[i].price, msg.price):
                    if remaining_qty >= self.resting[i].qty:
                        start_index = i + 1
                        if msg.send_trades:
                            self.send_execution(self.resting[i].price,
                                                self.resting[i].qty)
                        remaining_qty = remaining_qty - self.resting[i].qty
                    else:
                        if msg.send_trades:
                            self.send_execution(self.resting[i].price,
                                                remaining_qty)
                        if self.resting[i].qty == 0:
                            start_index = i + 1
                        else:
                            start_index = i
                        self.resting[i].qty = (self.resting[i].qty -
                                               remaining_qty)
                        remaining_qty = 0
            if remaining_qty > 0:
                pass
            self.resting = self.resting[start_index:len(self.resting)]
            if len(self.resting):
                self.quote(self.resting[0], L1_FEED, True)
            else:
                self.quote(Order(False, None, 0), L1_FEED, True)

    def process(self, data):
        raise "Book should never receive external messages"


class ExecutionEncoder(object):
    def encode(self, data):
        return struct.pack('>LfL', 8, data.price, data.qty)


class QuoteEncoder(object):
    def __init__(self, verbose=False):
        self.verbose = verbose

    def encode(self, data):
        if self.verbose:
            print "{} {} @ {}".format(data.kind, data.price, data.qty)
        price = data.price
        if price is None:
            price = 0.
        return struct.pack('>LsfL', 9, data.kind[0], price, data.qty)
