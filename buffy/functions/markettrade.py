#!/usr/bin/env python3

"""
Market Trade Processor

Based on
https://docs.google.com/document/d/1qpxeWcWeUzymX6hOSWG_yuTunNd6J2UoyWLzTOQiiz4/

"""

import state
import json


FUNC_NAME = 'Markettrade'


def func(input):
    # Deserialize input
    msg = json.loads(input)
    if msg['type'] == 'nbbo':
        process_order(msg)
    elif msg['type'] == 'order':
        process_order(msg)
    elif msg['type'] in ('fill', 'heartbeat'):
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
