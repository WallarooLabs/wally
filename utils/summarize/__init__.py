#!/usr/bin/env python3


import math
import json


def file_line_iter(fp):
    with open(fp, 'rb') as f:
        l = 1
        while l:
            l = f.readline()
            ll = l.decode().strip()
            if ll:
                yield ll


def two_file_line_iter(fp1, fp2):
    with open(fp1, 'rb') as sent, open(fp2, 'rb') as recd:
        ls = '\n'
        lr = '\n'
        while ls and lr:
            if ls == '\n':
                ls = sent.readline().decode().strip()
                continue
            if lr == '\n':
                lr = recd.readline().decode().strip()
                continue
            yield (ls, lr)
            ls = sent.readline().decode().strip()
            lr = recd.readline().decode().strip()


def parse_giles_line(l):
    ts, v = map(int, l.strip().split(', '))
    return (ts/1000000000.0, v)


def load_report(r):
    return json.loads(r)


class IncongruentReportError(Exception):
    pass


def verify_report(report):
    for p in report['payload']:
        t = sum(p['topics']['throughput_out'].values())
        l = sum(p['topics']['latency_bins'].values())
        if t != l:
            raise IncongruentReportError("Incongruent report found for:\n"
                "\ttopic: {}\n"
                "\tevent: {}:\n"
                "\tthroughput_out: {}\n"
                "\tlatency_bins: {}".format(report['topic'], report['event'],
                                           t, l))


Log10Bins = [0.000001, 0.00001, 0.0001, 0.001, 0.01, 0.1, 1.0, 10.0, 'overflow']
FixedBins = [0.000001, 0.00001, 0.0001, 0.001, 0.01, 0.05, 0.1, 0.15,
         0.2, 0.25, 0.3, 0.35, 0.4, 0.45, 0.5, 0.55, 0.6, 0.65, 0.7,
         0.75, 0.8, 0.85, 0.9, 0.95, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0,
         8.0, 9.0, 10.0, 'overflow']


def select_bin(v, bins):
    """Binary search bins keys for the smallest value that is greater than
    or equal to the value v."""
    if v > bins[-2]:
        return 'overflow'
#    elif v < bins[0]:
#        return bins[0]
    l = 0
    r = len(bins)-2
    m = (l+r)//2
    while True:
        b = bins[m]
        if (l == r) or ((r-l) == 1):
            break
        elif b < v:
            l = m
            m = (l+r)//2
        elif b >= v:
            r = m
            m = (l+r)//2
    b = bins[m]
    if v > b:
        return bins[m+1]
    return b


class Summarizer:
    def __init__(self, bins=Log10Bins):
        self.bins = bins
        self.counts = {b:0 for b in self.bins}
        self.throughputs = {}
        self.base = None

    def load(self, counts, throughputs):
        for k, v in counts.items():
            try:
                k = select_bin(float(k), self.bins)
            except:
                pass
            try:
                self.counts[k] += v
            except KeyError:
                self.counts[k] = v
        for t, v in throughputs.items():
            t = int(t)
            if self.base is None:
                self.base = t
            else:
                self.base = min(self.base, t)
            try:
                self.throughputs[t] += v
            except KeyError:
                self.throughputs[t] = v


    def count(self, t0, t1):
        dt = t1 - t0
        if dt > 0:
            v = select_bin(dt, self.bins)
        else:
            v = self.bins[0]
        self.counts[v] += 1
        t = int(math.ceil(t1))
        if self.base is None:
            self.base = t
        else:
            self.base = min(self.base, t)
        if t in self.throughputs:
            self.throughputs[t] += 1
        else:
            self.throughputs[t] = 1

    def __str__(self):
        return ("Throughput\n----------\n{}\n\n"
                "Latency\n-------\n{}".format(
            "\n".join(("{:<10}: {}".format(k-self.base, v)
                for k, v in sorted(self.throughputs.items(),
                    key=lambda x: x[0]))),
            "\n".join(("{:<10}: {}".format(k, self.counts[k])
                      for k in self.bins))))


def test_select_bin():
    assert(select_bin(5, FixedBins) == 5)
    assert(select_bin(4.95, FixedBins) == 5)
    assert(select_bin(4.99, FixedBins) == 5)
    assert(select_bin(3.95, FixedBins) == 4)
    assert(select_bin(4.0, FixedBins) == 4)
    assert(select_bin(0.149, FixedBins) == 0.15)
    assert(select_bin(0, FixedBins) == 0.000001)
    assert(select_bin(11, FixedBins) == 'overflow')
    assert(select_bin(0.005, Log10Bins) == 0.01)
    assert(select_bin(0.001, Log10Bins) == 0.001)


def test_summarizer():
    s = Summarizer()
    t0 = 14213851300
    for x in range(100):
        s.count(t0, t0 + 0.1)
    for k in s.counts.keys():
        if k == 'overflow':
            s.count(t0, t0 + 90.0)
        else:
            s.count(t0, t0 + (k - k/10.0))
    exp = """Throughput
----------
0         : 1
1         : 106
9         : 1
90        : 1

Latency
-------
1e-06     : 1
1e-05     : 1
0.0001    : 1
0.001     : 1
0.01      : 1
0.1       : 1
1.0       : 101
10.0      : 1
overflow  : 1"""
    assert(exp == str(s))

    s = Summarizer()
    thr = {5: 500, 6: 600, 7: 700}
    cnt = {0.1: 100, 0.001: 900, 0.0001: 800}
    s.load(cnt, thr)
    exp = """Throughput
----------
0         : 500
1         : 600
2         : 700

Latency
-------
1e-06     : 0
1e-05     : 0
0.0001    : 800
0.001     : 900
0.01      : 0
0.1       : 100
1.0       : 0
10.0      : 0
overflow  : 0"""
    assert(exp == str(s))
