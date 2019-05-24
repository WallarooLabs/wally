# Copyright 2017 The Wallaroo Authors.
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

"""
This is an example of a statelful application that takes a transaction object
and sends out an alert value if th transaction is above or below a threshold.
"""

import struct

import wallaroo
import wallaroo.experimental


def application_setup(args):
    source_config = wallaroo.experimental.SourceConnectorConfig(
        "alerts_feed",
        encoder=encode_feed,
        decoder=decode_feed,
        port=in_port,
        cookie="Dragons Love Tacos!",
        max_credits=10,
        refill_credits=8)
    sink_config = wallaroo.experimental.SinkConnectorConfig(
        "check_transaction",
        encoder=encode_alert,
        decoder=decode_alert,
        port=8901)
    # sink_config = wallaroo.TCPSinkConfig(out_host, out_port, encode_alert)
    pipeline = (
        wallaroo.source("Alerts (stateful)", source_config)
        .key_by(extract_user)
        .to(check_transaction_total)
        .to_sink(sink_config)
    )
    return wallaroo.build_application("Alerts (stateful)", pipeline)

class Transaction(object):
    def __init__(self, user, amount):
        self.user = user
        self.amount = amount


class TransactionTotal(object):
    def __init__(self):
        self.total = 0


class DepositAlert(object):
    def __init__(self, user, amount):
        self.user = user
        self.amount = amount

    def __str__(self):
        return "Deposit Alert for " + self.user + ": " + str(self.amount)


class WithdrawalAlert(object):
    def __init__(self, user, amount):
        self.user = user
        self.amount = amount

    def __str__(self):
        return "Withdrawal Alert for " + self.user + ": " + str(self.amount)

@wallaroo.key_extractor
def extract_user(transaction):
    return transaction.user


@wallaroo.state_computation(name="check transaction total", state=TransactionTotal)
def check_transaction_total(transaction, state):
    state.total = state.total + transaction.amount
    if state.total > 2000:
        return DepositAlert(transaction.user, state.total)
    elif state.total < -2000:
        return WithdrawalAlert(transaction.user, state.total)


@wallaroo.experimental.stream_message_encoder
def encode_alert(alert):
    return (str(alert) + "\n").encode('utf-8')

@wallaroo.experimental.stream_message_decoder
def decode_alert(alert):
    return data.decode('utf-8')

@wallaroo.experimental.stream_message_encoder
def encode_feed(data):
    return data

@wallaroo.experimental.stream_message_decoder
def decode_feed(data):
    user = struct.unpack(">4s", data[0:4])[0]
    amount = struct.unpack(">d",data[4:12])[0]
    return Transaction(user, amount)
