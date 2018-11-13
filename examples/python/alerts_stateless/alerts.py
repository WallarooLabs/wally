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
    print("!@0")

    gen_source = wallaroo.GenSourceConfig(TransactionsGenerator())

    print("!@1")
    transactions = wallaroo.source("Alerts (stateless)", gen_source)
    print("!@2")
    pipeline = (transactions
        .to(check_transaction)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder)))
    print("!@3")

    return wallaroo.build_application("Alerts (stateless)", pipeline)

class Transaction(object):
    def __init__(self, amount):
        self.amount = amount

class DepositAlert(object):
    def __init__(self, amount):
        self.amount = amount

    def __str__(self):
        return "Deposit Alert: " + str(self.amount)

class WithdrawalAlert(object):
    def __init__(self, amount):
        self.amount = amount

    def __str__(self):
        return "Withdrawal Alert: " + str(self.amount)

@wallaroo.computation(name="check transaction")
def check_transaction(transaction):
    if transaction.amount > 1000:
        return DepositAlert(transaction.amount)
    elif transaction.amount < -1000:
        return WithdrawalAlert(transaction.amount)

@wallaroo.encoder
def encoder(alert):
    return str(alert) + "\n"

############################################
# DEFINE A GENERATOR FOR ALERTS TEST INPUTS
############################################
class TransactionsGenerator(object):
    def initial_value(self):
        return Transaction(1)

    def apply(self, v):
        # A simplistic way to get some numbers above, below, and within our
        # thresholds.
        amount = ((((v.amount * 2305843009213693951) + 7) % 2500) - 1250)
        return Transaction(amount)
