#!/usr/bin/env python3

"""
Market Trade FIX Parser

"""


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

