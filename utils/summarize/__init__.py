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


P2Bins = list(range(66))


class Summarizer:
    def __init__(self, strip=False):
        self.bins = P2Bins
        self.counts = {b:0 for b in self.bins}
        self.throughputs = {}
        self.base = None
        self.strip = strip
        self._min_bin = self.bins[-1]
        self._max_bin = self.bins[0]

    def load(self, counts, throughputs):
        for k, v in counts.items():
            try:
                k = int(k)
            except:
                pass
            try:
                self.counts[k] += v
            except KeyError:
                self.counts[k] = v
            if k < self._min_bin:
                self._min_bin = k
            if k > self._max_bin:
                self._max_bin = k
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
            k = min(int(math.log(dt, 2)), 65)
        else:
            k = 0
        self.counts[k] += 1
        if k < self._min_bin:
            self._min_bin = k
        if k > self._max_bin:
            self._max_bin = k
        t = t1 // int(1e9)
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
            "\n".join(("{:<3}: {}".format(k, self.counts[k])
                      for k in self.bins if k >= self._min_bin and k <= self._max_bin))))


def test_summarizer():
    s = Summarizer(True)
    t0 = 14213851300 * int(1e9)
    for x in range(100):
        s.count(t0, t0 + int(1e7))
    for k in s.counts.keys():
        dt = int(1e9)*(k//10)
        s.count(t0 - 2**k + dt, t0 + dt)
    exp = """Throughput
----------
0         : 110
1         : 10
2         : 10
3         : 10
4         : 10
5         : 10
6         : 6

Latency
-------
0  : 1
1  : 1
2  : 1
3  : 1
4  : 1
5  : 1
6  : 1
7  : 1
8  : 1
9  : 1
10 : 1
11 : 1
12 : 1
13 : 1
14 : 1
15 : 1
16 : 1
17 : 1
18 : 1
19 : 1
20 : 1
21 : 1
22 : 1
23 : 101
24 : 1
25 : 1
26 : 1
27 : 1
28 : 1
29 : 1
30 : 1
31 : 1
32 : 1
33 : 1
34 : 1
35 : 1
36 : 1
37 : 1
38 : 1
39 : 1
40 : 1
41 : 1
42 : 1
43 : 1
44 : 1
45 : 1
46 : 1
47 : 1
48 : 1
49 : 1
50 : 1
51 : 1
52 : 1
53 : 1
54 : 1
55 : 1
56 : 1
57 : 1
58 : 1
59 : 1
60 : 1
61 : 1
62 : 1
63 : 1
64 : 1
65 : 1"""
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
0  : 1800"""
    assert(exp == str(s))
