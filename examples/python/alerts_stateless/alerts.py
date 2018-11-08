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
This is an example of a stateless application that takes a transaction
and sends an alert if its value is above or below a threshold.
"""

import wallaroo


def application_setup(args):
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    gen_source = wallaroo.GenSourceConfig(TransactionsGenerator())

    transactions = wallaroo.source("Alerts (stateless)", gen_source)
    pipeline = (transactions
        .to(check_transaction)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_alert)))

    return wallaroo.build_application("Alerts (stateless)", pipeline)

class Transaction(object):
    def __init__(self, tid, amount):
        self.id = tid
        self.amount = amount

class DepositAlert(object):
    def __init__(self, tid, amount):
        self.id = tid
        self.amount = amount

    def __str__(self):
        return "Deposit Alert for " + str(self.id) + ": " + str(self.amount)

class WithdrawalAlert(object):
    def __init__(self, tid, amount):
        self.id = tid
        self.amount = amount

    def __str__(self):
        return "Withdrawal Alert for " + str(self.id) + ": " + str(self.amount)

@wallaroo.computation(name="check transaction")
def check_transaction(transaction):
    if transaction.amount > 1000:
        return DepositAlert(transaction.id, transaction.amount)
    elif transaction.amount < -1000:
        return WithdrawalAlert(transaction.id, transaction.amount)

@wallaroo.encoder
def encode_alert(alert):
    return (str(alert) + "\n").encode()

############################################
# DEFINE A GENERATOR FOR ALERTS TEST INPUTS
############################################
class TransactionsGenerator(object):
    tid = 0

    def initial_value(self):
        return Transaction(0, 1)

    def apply(self, v):
        # A simplistic way to get some numbers above, below, and within our
        # thresholds.
        amount = ((((v.amount * 2305843009213693951) + 7) % 2500) - 1250)
        self.tid = self.tid + 1
        return Transaction(self.tid, amount)
