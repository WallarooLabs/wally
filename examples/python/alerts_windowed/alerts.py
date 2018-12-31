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

    transactions = wallaroo.source("Alerts (windowed)", gen_source)
    pipeline = (transactions
        .key_by(extract_user)
        .to(wallaroo.range_windows(wallaroo.seconds(9))
            .with_slide(wallaroo.seconds(3))
            .over(TotalAggregation))
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_alert)))

    return wallaroo.build_application("Alerts (windowed)", pipeline)


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


class TotalAggregation(wallaroo.Aggregation):
    def initial_accumulator(self):
        return TransactionTotal()

    def update(self, transaction, t_total):
        t_total.total = t_total.total + transaction.amount

    def combine(self, t1, t2):
        new_t = TransactionTotal()
        new_t.total = t1.total + t2.total
        return new_t

    def output(self, user, t):
        print("!@TotalAggregation: Triggering output")
        if t.total > 2000:
            return DepositAlert(user, t.total)
        elif t.total < -2000:
            return WithdrawalAlert(user, t.total)


@wallaroo.encoder
def encode_alert(alert):
    return (str(alert) + "\n").encode()


############################################
# DEFINE A GENERATOR FOR ALERTS TEST INPUTS
############################################
class TransactionsGenerator(object):
    def __init__(self):
        self.user_idx = 0
        self.user_totals = [1, 0, 0, 0, 0]
        self.users = ["Fido", "Rex", "Dr. Whiskers", "Feathers", "Mountaineer"]

    def initial_value(self):
        return Transaction("Fido", 1)

    def apply(self, v):
        # A simplistic way to get some numbers above, below, and within our
        # thresholds.
        amount = ((((v.amount * 2305843009213693951) + 7) % 2500) - 1250)
        self.user_idx = (self.user_idx + 1) % len(self.users)
        user = self.users[self.user_idx]
        total = self.user_totals[self.user_idx]
        if total > 5000:
            amount = -6000
        elif total < -5000:
            amount = 6000
        self.user_totals[self.user_idx] = total + amount
        return Transaction(user, amount)
