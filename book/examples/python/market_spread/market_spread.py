import struct
import time

import wallaroo


FIXTYPE_ORDER = 1
FIXTYPE_MARKET_DATA = 2

SIDETYPE_BUY = 1
SIDETYPE_SELL = 2


def test_python():
    return "hello python"


def str_to_partition(stringable):
    ret = 0
    for x in range(0, len(stringable)):
        ret += ord(stringable[x]) << (x * 8)
    return ret


def load_valid_symbols():
    with open('symbols.txt', 'rb') as f:
        return f.read().splitlines()


def application_setup(args):
    symbol_partitions = [str_to_partition(x.rjust(4)) for x in
                         load_valid_symbols()]

    ab = wallaroo.ApplicationBuilder("market-spread")
    ab.new_pipeline(
            "Orders", OrderDecoder()
        ).to_state_partition_u64(
            CheckOrder(), SymbolDataBuilder(), "symbol-data",
            SymbolPartitionFunction(), symbol_partitions
       ).to_sink(
            OrderResultEncoder()
       ).new_pipeline(
            "Market Data", MarketDataDecoder()
        ).to_state_partition_u64(
            UpdateMarketData(), SymbolDataBuilder(), "symbol-data",
            SymbolPartitionFunction(), symbol_partitions
        ).done()
    return ab.build()


class MarketSpreadError(Exception):
    pass


class SymbolData(object):
    def __init__(self, last_bid, last_offer, should_reject_trades):
        self.last_bid = last_bid
        self.last_offer = last_offer
        self.should_reject_trades = should_reject_trades


class SymbolDataBuilder(object):
    def build(self):
        return SymbolData(0.0, 0.0, True)


class SymbolPartitionFunction(object):
    def partition(self, data):
        return str_to_partition(data.symbol)


class CheckOrder(object):
    def name(self):
        return "Check Order"

    def compute(self, data, state):
        if state.should_reject_trades:
            print "rejecting"
            ts = int(time.time() * 100000)
            return OrderResult(data, state.last_bid,
                               state.last_offer, ts)
        return None


class Order(object):
    def __init__(self, side, account, order_id, symbol, qty, price,
                 transact_time):
        self.side = side
        self.account = account
        self.order_id = order_id
        self.symbol = symbol
        self.qty = qty
        self.price = price
        self.transact_time = transact_time


class OrderDecoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        """
        0 -  1b - FixType (U8)
        1 -  1b - side (U8)
        2 -  4b - account (U32)
        6 -  6b - order id (String)
        12 -  4b - symbol (String)
        16 -  8b - order qty (F64)
        24 -  8b - price (F64)
        32 - 21b - transact_time (String)
        """
        order_type = struct.unpack(">B", bs[0:1])[0]
        if order_type != FIXTYPE_ORDER:
            raise MarketSpreadError("Wrong Fix message type. Did you connect "
                                    "the senders the wrong way around?")
        side = struct.unpack(">B", bs[1:2])[0]
        account = struct.unpack(">I", bs[2:6])[0]
        order_id = struct.unpack("6s", bs[6:12])[0]
        symbol = struct.unpack("4s", bs[12:16])[0]
        qty = struct.unpack(">d", bs[16:24])[0]
        price = struct.unpack(">d", bs[24:32])[0]
        transact_time = struct.unpack("21s", bs[32:53])[0]

        return Order(side, account, order_id, symbol, qty, price,
                     transact_time)


class OrderResult(object):
    def __init__(self, order, last_bid, last_offer, timestamp):
        self.order = order
        self.bid = last_bid
        self.offer = last_offer
        self.timestamp = timestamp


class OrderResultEncoder(object):
    def encode(self, data):
        # data is a string
        msg_size = 1 + 4 + 6 + 4 + 8 + 8 + 8 + 8 + 8
        p = struct.pack(">IHI6s4sddddQ",
                        msg_size,
                        data.order.side,
                        data.order.account,
                        data.order.order_id,
                        data.order.symbol,
                        data.order.qty,
                        data.order.price,
                        data.bid,
                        data.offer,
                        data.timestamp)
        return p


class MarketDataMessage(object):
    def __init__(self, symbol, transact_time, bid, offer):
        self.symbol = symbol
        self.transact_time = transact_time
        self.bid = bid
        self.offer = offer
        self.mid = (bid + offer) / 2.0


class MarketDataDecoder(object):
    def header_length(self):
        return 4

    def payload_length(self, bs):
        return struct.unpack(">I", bs)[0]

    def decode(self, bs):
        """
        0 -  1b - FixType (U8)
        1 -  4b - symbol (String)
        5 -  21b - transact_time (String)
        26 - 8b - bid_px (F64)
        34 - 8b - offer_px (F64)
        """
        order_type = struct.unpack(">B", bs[0:1])[0]
        if order_type != FIXTYPE_MARKET_DATA:
            raise MarketSpreadError("Wrong Fix message type. Did you connect "
                                    "the senders the wrong way around?")
        symbol = struct.unpack(">4s", bs[1:5])[0]
        transact_time = struct.unpack(">21s", bs[5:26])[0]
        bid = struct.unpack(">d", bs[26:34])[0]
        offer = struct.unpack(">d", bs[34:42])[0]
        return MarketDataMessage(symbol, transact_time, bid, offer)


class UpdateMarketData(object):
    def name(self):
        return "Update Market Data"

    def compute(self, data, state):
        offer_bid_difference = data.offer - data.bid

        should_reject_trades = ((offer_bid_difference >= 0.05) or
                                ((offer_bid_difference / data.mid) >= 0.05))

        state.last_bid = data.bid
        state.last_offer = data.offer
        state.should_reject_trades = should_reject_trades

        if should_reject_trades:
            print "Should reject trades"
        return None
