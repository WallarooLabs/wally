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

    transactions = wallaroo.source("Alerts (stateful)", gen_source)
    pipeline = (transactions
        .to(check_transaction_total)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encoder)))

    return wallaroo.build_application("Alerts (stateful)", pipeline)

class Transaction(object):
    def __init__(self, amount):
        self.amount = amount

class TransactionTotal(object):
    total = 0

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

@wallaroo.state_computation(name="check transaction total", state=TransactionTotal)
def check_transaction_total(transaction, state):
    state.total = state.total + transaction.amount
    if state.total > 2000:
        return DepositAlert(state.total)
    elif state.total < -2000:
        return WithdrawalAlert(state.total)

@wallaroo.encoder
def encoder(alert):
    return str(alert) + "\n"

############################################
# DEFINE A GENERATOR FOR ALERTS TEST INPUTS
############################################
class TransactionsGenerator(object):
    total = 1

    def initial_value(self):
        return Transaction(1)

    def apply(self, v):
        # A simplistic way to get some numbers above, below, and within our
        # thresholds.
        amount = ((((v.amount * 2305843009213693951) + 7) % 2500) - 1250)
        if total > 5000:
            amount = -6000
        elif total < -5000:
            amount = 6000
        total = total + amount
        return Transaction(amount)
