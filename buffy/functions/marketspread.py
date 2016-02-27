#!/usr/bin/env python3

"""
Market Trade Processor

Based on
https://docs.google.com/document/d/1qpxeWcWeUzymX6hOSWG_yuTunNd6J2UoyWLzTOQiiz4/

"""

from . import state


FUNC_NAME = 'Marketspread'


def func(input):
    # Deserialize input
    msg = parse_fix(input)
    if msg['MsgType'] == 'nbbo':
        return process_order(msg)
    elif msg['MsgType'] == 'order':
        return process_order(msg)
    elif msg['MsgType'] in ('fill', 'heartbeat'):
        return None



def process_nbbo(msg):
    # Update market info in memory
    state.get_attribute('market', {})[msg['symbol']] = {
        'id': msg['id'],
        'last_msg_time': msg['time'],
        'symbol': msg['symbol'],
        'bid': msg['bid'],
        'offer': msg['offer'],
        'mid': (msg['bid'] + msg['offer'])/2,
        'stop_new_orders': ((msg['offer'] - msg['bid']) >= 0.05 and
                            (msg['offer'] - msg['bid']) >= 0.05)}
    return None


def process_order(msg):
    # Orders
    if msg['type'] == 'order':
        # Reject order if: order already exists, the symbol has
        # stop_new_orders set to True or ???
        if (msg['order'] in state.get_attribute('orders', {}) or
            state.get_attribute('market',
                                {})[msg['symbol']]['stop_new_orders']):
            return reject_order(msg)

        # otherwise, accept the order
        return accept_order(msg)


def reject_order(msg):
    pass


def accept_order(msg):
    pass


SOH = '\x01'
# See http://www.onixs.biz/fix-dictionary/4.2/fields_by_tag.html
# for complete tag definitions
MSG_TYPES = {'0': 'heartbeat',
             'D': 'order',}
SIDES = {'1': 'buy',
         '2': 'sell',}
TAGS = {'0': ('MessageId', str),
        '1': ('Account', str),
        '11': ('OrderId', str),
        '35': ('MsgType', lambda v: MSG_TYPES.get(v, None)),
        '37': ('OrderId', str),
        '38': ('OrderQty', float),
        '39': ('OrdStatus', str),
        '44': ('Price', float),
        '54': ('Side', lambda v: SIDES.get(v, None)),
        '55': ('Symbol', str),
        '60': ('TransactTime', str),
        '107': ('SecurityDesc', str),
        '132': ('BidPx', float),
        '133': ('OfferPx', float),}


def parse_fix(input):
    tuples = [part.split('=') for part in input.split(SOH)]
    output = {TAGS[tup[0]][0]: TAGS[tup[0]][1](tup[1]) for tup in tuples
              if tup[0] in TAGS}
    return output


# TESTS #
def test_parse_fix():
    input = ('8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01'
             '21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01'
             '55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01'
             '10=108\x01')
    expected = {'Account': 'CLIENT35', 'OrderQty': 4000.0, 'Symbol': 'TSLA',
                'Price': 252.85366153511416, 'OrderId': 's0XCIa',
                'TransactTime': '20151204-14:30:00.000',
                'SecurityDesc': 'Tesla Motors', 'Side': 'buy',
                'MsgType': 'order'}

    output = parse_fix(input)
    assert(output == expected)


def test_func():
    input = ('8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01'
             '21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01'
             '55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01'
             '10=108\x01')

   func(input)

   assert(0)
