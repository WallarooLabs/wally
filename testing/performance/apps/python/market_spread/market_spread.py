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


from enum import IntEnum
import struct
import time

import wallaroo


FIXTYPE_ORDER = 1
FIXTYPE_MARKET_DATA = 2

SIDETYPE_BUY = 1
SIDETYPE_SELL = 2


def application_setup(args):
    input_addrs = wallaroo.tcp_parse_input_addrs(args)
    inputs = {ip[0]: {"host": ip[1], "port": ip[2]} for ip in input_addrs}

    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    orders = wallaroo.source("Orders",
        wallaroo.TCPSourceConfig("Orders", inputs["Orders"]["host"],
                                 inputs["Orders"]["port"],
                                 decode_order))

    market_data = wallaroo.source("Market Data",
        wallaroo.TCPSourceConfig("Market Data", inputs["Market Data"]["host"],
                                 inputs["Market Data"]["port"],
                                 decode_market_data))

    pipeline = (orders.merge(market_data)
        .key_by(extract_symbol)
        .to(check_market_data)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port,
                                        order_result_encoder)))

    return wallaroo.build_application("Market Spread", pipeline)


class SerializedTypes(IntEnum):
    """
    Define the types of data that can be serialised
    """
    CHECKMARKETDATA = 1
    EXTRACTSYMBOL = 2
    ORDERRESULTENCODER = 3
    MARKETDATAMESSAGE = 4
    MARKETDATADECODER = 5
    ORDERMESSAGE = 6
    ORDERDECODER = 7
    SYMBOLDATA = 8


def serialize(o):
    """
    Pack objects according to the following schema:
    0 - 4b object class (SerializedTypes)
    1 - ?b object data (if required)
    """
    if isinstance(o, check_market_data.__class__):
        s = struct.Struct(">I")
        return s.pack(SerializedTypes.CHECKMARKETDATA)
    elif isinstance(o, extract_symbol.__class__):
        s = struct.Struct(">I")
        return s.pack(SerializedTypes.EXTRACTSYMBOL)
    elif isinstance(o, order_result_encoder.__class__):
        s = struct.Struct(">I")
        return s.pack(SerializedTypes.ORDERRESULTENCODER)
    elif isinstance(o, MarketDataMessage):
        s = struct.Struct(">I4s21sdd")
        return s.pack(SerializedTypes.MARKETDATAMESSAGE,
                      o.symbol, o.transact_time, o.bid, o.offer)
    elif isinstance(o, market_data_decoder.__class__):
        s = struct.Struct(">I")
        return s.pack(SerializedTypes.MARKETDATADECODER)
    elif isinstance(o, Order):
        s = struct.Struct(">IBI6s4sdd21s")
        return s.pack(SerializedTypes.ORDERMESSAGE, o.side, o.account,
                      o.order_id, o.symbol, o.qty, o.price, o.transact_time)
    elif isinstance(o, order_decoder.__class__):
        s = struct.Struct(">I")
        return s.pack(SerializedTypes.ORDERDECODER)
    elif isinstance(o, SymbolData):
        s = struct.Struct(">Idd?")
        return s.pack(SerializedTypes.SYMBOLDATA,
            o.last_bid, o.last_offer, o.should_reject_trades)
    else:
        print("Don't know how to serialize {}".format(type(o).__name__))
    return None


def deserialize(bs):
    """
    Unpack objects according to the following schema:
    0 - 4b object class (SerializedTypes)
    1 - ?b object data (if required)
    """
    (obj_type,), bs = struct.unpack(">I", bs[:4]), bs[4:]
    if obj_type == SerializedTypes.CHECKMARKETDATA:
        return check_market_data
    elif obj_type == SerializedTypes.EXTRACTSYMBOL:
        return extract_symbol
    elif obj_type == SerializedTypes.ORDERRESULTENCODER:
        return order_result_encoder
    elif obj_type == SerializedTypes.MARKETDATAMESSAGE:
        (symbol, time, bid, offer) = struct.unpack(">4s21sdd", bs)
        return MarketDataMessage(symbol, time, bid, offer)
    elif obj_type == SerializedTypes.MARKETDATADECODER:
        return market_data_decoder
    elif obj_type == SerializedTypes.ORDERMESSAGE:
        (side, acct, oid, symbol, qty, price, t_time) = struct.unpack(
                ">BI6s4sdd21s", bs)
        return Order(side, acct, oid, symbol, qty, price, t_time)
    elif obj_type == SerializedTypes.ORDERDECODER:
        return order_decoder
    elif obj_type == SerializedTypes.SYMBOLDATA:
        (last_bid, last_offer, should_reject_trades) = struct.unpack(">dd?", bs)
        return SymbolData(last_bid, last_offer, should_reject_trades)
    else:
        print("Don't know how to deserialize: {}".format(obj_type))
    return None


class MarketSpreadError(Exception):
    pass


class SymbolData(object):
    def __init__(self, last_bid=0.0, last_offer=0.0, should_reject_trades=True):
        self.last_bid = last_bid
        self.last_offer = last_offer
        self.should_reject_trades = should_reject_trades


@wallaroo.key_extractor
def extract_symbol(data):
    return data.symbol


@wallaroo.state_computation(name="Check Market Data", state=SymbolData)
def check_market_data(data, state):
    if data.is_order:
        if state.should_reject_trades:
            ts = int(time.time() * 100000)
            return OrderResult(data, state.last_bid, state.last_offer, ts)
        return None
    else:
        offer_bid_difference = data.offer - data.bid
        should_reject_trades = ((offer_bid_difference >= 0.05) or
                                ((offer_bid_difference / data.mid) >= 0.05))
        state.last_bid = data.bid
        state.last_offer = data.offer

        state.should_reject_trades = should_reject_trades
        return None


class Order(object):
    def __init__(self, side, account, order_id, symbol, qty, price,
                 transact_time):
        self.is_order = True
        self.side = side
        self.account = account
        self.order_id = order_id
        self.symbol = symbol
        self.qty = qty
        self.price = price
        self.transact_time = transact_time


class MarketDataMessage(object):
    def __init__(self, symbol, transact_time, bid, offer):
        self.is_order = False
        self.symbol = symbol
        self.transact_time = transact_time
        self.bid = bid
        self.offer = offer
        self.mid = (bid + offer) / 2.0


@wallaroo.decoder(header_length=4, length_fmt=">I")
def order_decoder(bs):
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


@wallaroo.decoder(header_length=4, length_fmt=">I")
def market_data_decoder(bs):
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


class OrderResult(object):
    def __init__(self, order, last_bid, last_offer, timestamp):
        self.order = order
        self.bid = last_bid
        self.offer = last_offer
        self.timestamp = timestamp


@wallaroo.encoder
def order_result_encoder(data):
    p = struct.pack(">HI6s4sddddQ",
                    data.order.side,
                    data.order.account,
                    data.order.order_id,
                    data.order.symbol,
                    data.order.qty,
                    data.order.price,
                    data.bid,
                    data.offer,
                    data.timestamp)
    out = struct.pack(">I{}s".format(len(p)), len(p), p)
    return out
