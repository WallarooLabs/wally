from json import loads
from math import floor
import numpy as np


def parse_output_line(line):
    key, val, t0, t1 = map(int, line.strip().split(','))
    return key, val, int(floor(t1/1e9)), (t1/1e9 - t0/1e9)


def load_output_file(path):
    aggs = {}
    with open(path, 'rt') as f:
        f.readline()
        for line in f.readlines():
            if line:
                key, val, bucket, latency = parse_output_line(line)
                aggs.setdefault(bucket, []).append(latency)
            else:
                continue
    # convert time to offset from start
    # And convert array of latencies to percentiles:
    percentiles = [0, 25, 50, 75, 90, 95, 99.9, 99, 99.99, 100]
    initial_keys = list(aggs.keys())
    t0 = min(initial_keys)
    for ik in initial_keys:
        arr = np.array(aggs.pop(ik))
        aggs[ik] = {'percentiles': [(p, np.percentile(arr, p))
                                       for p in percentiles],
                       'count': len(arr)}
    return aggs


def parse_checkpoints(data):
    timestamps, delays, sizes, ids = [], [], [], []
    t0 = data[0]['ts']
    last_t = t0
    last_id = list(data[0]['checkpoint_ids'].values())[0]
    for rec in data:
        timestamps.append(rec['ts'])
        if list(rec['checkpoint_ids'].values())[0] > last_id:
            delays.append(rec['ts'] - last_t)
            last_id = list(rec['checkpoint_ids'].values())[0]
        last_t = rec['ts']
        sizes.append(list(rec['log_bytes'].values())[0])
        ids.append(list(rec['checkpoint_ids'].values())[0])
    return {'timestamps': timestamps, 'delays': delays,
            'sizes': sizes, 'ids': ids}


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
