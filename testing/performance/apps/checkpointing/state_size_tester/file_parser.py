from json import loads
from math import floor
import numpy as np
import os


PERCENTILES = [0, 25, 50, 75, 90, 95, 99.9, 99, 99.99, 100]


def parse_output_line(line):
    key, val, t0, t1 = map(int, line.strip().split(','))
    return key, val, int(floor(t1/1e9)), (t1/1e9 - t0/1e9)


def load_output_file(path):
    aggs = {}
    with open(path, 'rt') as f:
        f.readline()
        for line in f.readlines():
            if line:
                try:
                    key, val, bucket, latency = parse_output_line(line)
                    aggs.setdefault(bucket, []).append(latency)
                except:
                    print("Ignoring {}".format(line))
            else:
                continue
    # convert time to offset from start
    # And convert array of latencies to percentiles:
    initial_keys = list(aggs.keys())
    t0 = min(initial_keys)
    for ik in initial_keys:
        arr = np.array(aggs.pop(ik))
        aggs[ik] = {'percentiles': [(p, np.percentile(arr, p))
                                       for p in PERCENTILES],
                       'count': len(arr)}
    return aggs


def parse_checkpoints(data):
    out = {}
    for rec in data:
        # key on second, but record full precision timestamp (as fractional second)
        key = int(floor(rec['ts']/1e9))
        for fn in rec['log_bytes'].keys():
            f_key = os.path.splitext(fn)[0]
            f_data = out.setdefault(f_key, {})
            r_data = f_data.setdefault(key, {})
            r_data['ts'] = rec['ts']/1e9
            r_data['size'] = rec['log_bytes'][fn]
            r_data['id'] = rec['checkpoint_ids'][f_key + '.checkpoint_ids']
    return out


def load_checkpoints_file(path):
    data = []
    with open(path, 'r') as f:
        for line in f.readlines():
            if line:
                try:
                    data.append(loads(line.strip('\n')))
                except:
                    print("bad line")
                    print(repr(line))
                    raise
    return parse_checkpoints(data)
