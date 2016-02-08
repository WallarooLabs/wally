#!/usr/bin/env python3

"""Market Trade Processor

Based on https://docs.google.com/document/d/1qpxeWcWeUzymX6hOSWG_yuTunNd6J2UoyWLzTOQiiz4/

Logic:
per message:
 if message is Market/NBBO:
  # Compute: Mid = (bid+offer)/2
  # Compute stop_new_orders = (offer-bid)/mid >= 0.05 AND (offer-bid) >= $0.05
  save market[symbol] = {id: id, last_msg_time: time, symbol: symbol, bid: bid,   offer: bid, mid: Mid, stop_new_orders: stop_new_orders}
 else:
  ignore

 if message is Trade:
  if type is Order:
   if order is valid:
    save order[order_id] = {order data}
    emit order accepted message
   else:
    emit order rejected message
  if type is fill:
   if valid trade:
    update order data and emit trade accepted message
   else:
    emit trade rejected message
  else:
   ignore

"""

import state
import json


FUNC_NAME = 'Markettrade'


def func(input):
    # Deserialize input
    msg = json.loads(input)
    if msg['stream_type'] == 'nbbo':
        # Update market info in memory
        state.get_attribute('market', {})[msg['symbol']] = {
            'id': msg['id'],
            'last_msg_time': msg['time'],
            'symbol': msg['symbol'],
            'bid': msg['bid'],
            'offer': msg['offer'],
            'mid': (msg['bid'] + msg['offer'])/2,
            'stop_new_orders': ((msg['offer'] - msg['bid']) >= 0.05 AND
                                (msg['offer'] - msg['bid']) >= 0.05)}

    elif msg['stream_type'] == 'order':
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

        # Fills
        elif msg['type'] == 'fill':
            order = state.get_attribute('order', {})
            if msg['order'] not in order:
                return reject_trade(msg)

            # check if the quantity in the fill overflows the order target
            if (order[msg['order']]['quantity'] -
                order[msg['order']]['filled']) > msg['quantity']:
                return reject_trade(msg)

            # process trade
            mult = 1 if order[msg['order']]['side'] == 'buy' else -1
            order[msg['order']]['filled'] += mult*msg['quantity']
            return accept_trade(msg)



def reject_order(msg):
    pass


def accept_order(msg):
    pass


def reject_trade(msg):
    pass


def accept_trade(msg):
    pass

