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
        return process_nbbo(msg)
    elif msg['MsgType'] == 'order':
        return process_order(msg)
    elif msg['MsgType'] in ('fill', 'heartbeat'):
        return None



def process_nbbo(msg):
    # Update market info in memory
    mid = (msg['BidPx'] + msg['OfferPx'])/2
    state.get_attribute('market', {})[msg['Symbol']] = {
        #'id': msg['id'],
        'time': msg['TransactTime'],
        'symbol': msg['Symbol'],
        'bid': msg['BidPx'],
        'offer': msg['OfferPx'],
        'mid': mid,
        'stop_new_orders': (((msg['OfferPx'] - msg['BidPx'])/mid) >= 0.05 and
                            (msg['OfferPx'] - msg['BidPx']) >= 0.05)}
    return None


def process_order(msg):
    # Orders
    orders = state.get_attribute('orders', {})
    market = state.get_attribute('market', {})
    if msg['MsgType'] == 'order':
        # Reject order if: order already exists, the symbol has
        # stop_new_orders set to True or ???
        if msg['OrderId'] in orders:
            return reject_order(msg, 'Order already exists')
        elif not msg['Symbol'] in market:
            return reject_order(msg,
                                'Unknown symbol: {}'.format(msg['Symbol']))
        elif market[msg['Symbol']]['stop_new_orders']:
            return reject_order(msg,
                                '{} - Stop New Orders'.format(msg['Symbol']))

        # otherwise, accept the order
        return accept_order(msg)


def reject_order(msg, reason):
    return ("New Order: ({client}, {symbol}, {status}, {quantity}): "
            "{status}: {reason}".format(client=msg['Account'],
                              symbol=msg['Symbol'],
                              quantity=msg.get('OrderQty', None),
                              status='Rejected',
                              reason=reason))


def accept_order(msg):
    state.get_attribute('orders', {})[msg['OrderId']] = msg
    return ("New Order: ({client}, {symbol}, {status}, {quantity}): "
            "{status}".format(client=msg['Account'],
                              symbol=msg['Symbol'],
                              quantity=msg.get('OrderQty', None),
                              status='Accepted'))


SOH = '\x01'
# See http://www.onixs.biz/fix-dictionary/4.2/fields_by_tag.html
# for complete tag definitions
MSG_TYPES = {'0': 'heartbeat',
             'D': 'order',
             'S': 'nbbo',}
SIDES = {'1': 'buy',
         '2': 'sell',}
TAGS = {'0': ('MessageId', str),
        '1': ('Account', str),
        '8': ('BeginString', str),
        '9': ('BodyLength', int),
        '10': ('CheckSum', str),
        '11': ('OrderId', str),
        '21': ('HandlInst', str),
        '35': ('MsgType', lambda v: MSG_TYPES.get(v, None)),
        '37': ('OrderId', str),
        '38': ('OrderQty', float),
        '39': ('OrdStatus', str),
        '40': ('OrdType', str),
        '44': ('Price', float),
        '54': ('Side', lambda v: SIDES.get(v, None)),
        '55': ('Symbol', str),
        '60': ('TransactTime', str),
        '107': ('SecurityDesc', str),
        '117': ('QuoteId', str),
        '132': ('BidPx', float),
        '133': ('OfferPx', float),}


def parse_fix(input):
    tuples = [part.split('=') for part in input.split(SOH)]
    output = {TAGS[tup[0]][0]: TAGS[tup[0]][1](tup[1]) for tup in tuples
              if tup[0] in TAGS}
    return output


# TESTS #
def test_parse_fix_trade():
    input = ('8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01'
             '21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01'
             '55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01'
             '10=108\x01')
    expected = {'Side': 'buy', 'TransactTime': '20151204-14:30:00.000',
                'Account': 'CLIENT35', 'MsgType': 'order', 'BodyLength': 121,
                'OrderId': 's0XCIa', 'BeginString': 'FIX.4.2',
                'SecurityDesc': 'Tesla Motors', 'Symbol': 'TSLA',
                'CheckSum': '108', 'OrderQty': 4000.0, 'HandlInst': '3',
                'Price': 252.85366153511416, 'OrdType': '2'}

    output = parse_fix(input)
    assert(output == expected)


def test_parse_fix_nbbo():
    state.pop('market', None)
    state.pop('order', None)
    input = ('8=FIX.4.2\x019=64\x0135=S\x0155=TSLA\x01'
             '60=20151204-14:30:00.000\x01117=S\x01132=16.40\x01133=16.60'
             '\x0110=098\x01')
    expected = {'MsgType': 'nbbo', 'QuoteId': 'S', 'BodyLength': 64,
                'BidPx': 16.40, 'OfferPx': 16.60, 'Symbol': 'TSLA',
                'BeginString': 'FIX.4.2', 'CheckSum': '098',
                'TransactTime': '20151204-14:30:00.000'}
    output = parse_fix(input)
    assert(output == expected)
    output = func(input)
    symbol = state.get_attribute('market', {}).get('TSLA')
    assert(symbol['stop_new_orders'] is False)
    assert(symbol['bid'] == 16.40)
    assert(symbol['offer'] == 16.60)
    assert(symbol['mid'] == 16.50)


def test_func():
    state.pop('market', None)
    state.pop('order', None)
    input = ('8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01'
             '21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01'
             '55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01'
             '10=108\x01')
    expected = ('New Order: (CLIENT35, TSLA, Rejected, 4000.0): Rejected: '
                'Unknown symbol: TSLA')
    output = func(input)
    assert(output == expected)

    input = ('8=FIX.4.2\x019=64\x0135=S\x0155=TSLA\x01'
             '60=20151204-14:30:00.000\x01117=S\x01132=16.40\x01133=16.60'
             '\x0110=098\x01')
    func(input)

    symbol = state.get_attribute('market', {}).get('TSLA')
    assert(symbol)
    input = ('8=FIX.4.2\x019=121\x0135=D\x011=CLIENT35\x0111=s0XCIa\x01'
             '21=3\x0138=4000\x0140=2\x0144=252.85366153511416\x0154=1\x01'
             '55=TSLA\x0160=20151204-14:30:00.000\x01107=Tesla Motors\x01'
             '10=108\x01')
    expected = 'New Order: (CLIENT35, TSLA, Accepted, 4000.0): Accepted'
    output = func(input)
    assert(output == expected)
