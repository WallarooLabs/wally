import struct

class Ring(object):
    def __init__(self):
        self.r = [0,0,0,0]

    def push(self, v):
        self.r.pop(0)
        self.r.append(v)

    def __str__(self):
        return "[{}]".format(",".join("{}".format(v) for v in self.r))

fmt = '>LQ{}s'

def inc_and_write(x,f):
    global timestamp
    if x % 2 == 0:
        r0.push(x)
        s = str(r0)
        f.write(struct.pack(fmt.format(len(s)), len(s), timestamp, s))
        timestamp += 1
    else:
        r1.push(x)
        s = str(r1)
        f.write(struct.pack(fmt.format(len(s)), len(s), timestamp, s))
        timestamp += 1

def inc(x):
    global timestamp
    timestamp += 1
    if x % 2 == 0:
        r0.push(x)
    else:
        r1.push(x)


# Pass
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('pass.txt', 'wb') as f:
    for x in xrange(1,1001):
        inc_and_write(x,f)


# Fail expect_max
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_expect_max.txt', 'wb') as f:
    for x in xrange(1,1003):
        inc_and_write(x,f)


# Fail increments
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_increments.txt', 'wb') as f:
    for x in xrange(1,101):
        inc_and_write(x,f)
    for x in xrange(81, 1001):
        inc_and_write(x,f)


# Fail sequentiality
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_sequentiality.txt', 'wb') as f:
    for x in xrange(1,101):
        inc_and_write(x,f)
    for x in xrange(101,111):
        inc(x)
    for x in xrange(111, 1001):
        inc_and_write(x,f)


# Fail size
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_size.txt', 'wb') as f:
    for x in xrange(1,101):
        inc_and_write(x,f)
    r0.r.insert(0, 92)
    for x in xrange(101,111):
        inc_and_write(x,f)
    r0.r.pop(0)
    for x in xrange(111,1001):
        inc_and_write(x,f)


# Fail no nonlead zeroes
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_no_nonlead_zeroes.txt', 'wb') as f:
    for x in xrange(1,101):
        inc_and_write(x,f)
    r0.push(0)
    for x in xrange(101,1001):
        inc_and_write(x,f)


# Fail parity
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_parity.txt', 'wb') as f:
    for x in xrange(1,101):
        inc_and_write(x,f)
    r0.push(101)  # push 101 to the even partition
    for x in xrange(102,1001):
        inc_and_write(x,f)


# Fail expected difference
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('fail_expected_difference.txt', 'wb') as f:
    for x in xrange(1,999):
        inc_and_write(x,f)
    inc_and_write(1000, f)


# Pass with at-least-once mode (fail sequentiality without)
r0 = Ring()
r1 = Ring()
timestamp = 0
with open('pass_with_atleastonce.txt', 'wb') as f:
    for x in xrange(1,501):
        inc_and_write(x,f)
    r0.r = [394,396,398,400]
    r1.r = [393,395,397,399]
    for x in range(401,1001):
        inc_and_write(x,f)
