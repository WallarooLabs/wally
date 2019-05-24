import os
import struct

############################################
# DEFINE A GENERATOR FOR ALERTS TEST INPUTS
############################################
class TransactionsGenerator(object):
    user_idx = 0
    user_totals = [1, 0, 0, 0, 0]
    users = ["Fido", "Mack", "Linx", "Chip", "Otis"]

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

class Transaction(object):
    def __init__(self, user, amount):
        self.user = user
        self.amount = amount

#get local path
BASE_PATH = os.path.dirname(os.path.realpath(__file__))
file_name = "alerts.msg"
generator = TransactionsGenerator()
with open(os.path.join(BASE_PATH, file_name), 'wb') as f:
    t = generator.initial_value()
    encoded_t = struct.pack(">4sd", t.user, t.amount)
    f.write(struct.pack(">I{}s".format(len(encoded_t)), len(encoded_t), encoded_t))
    for x in range(1,100):
        t = generator.apply(t)
        encoded_t = struct.pack(">4sd", t.user, t.amount)
        f.write(struct.pack(">I{}s".format(len(encoded_t)), len(encoded_t), encoded_t))

