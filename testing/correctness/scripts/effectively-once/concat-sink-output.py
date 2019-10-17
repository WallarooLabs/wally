#!/usr/bin/env python3

import sys

def get_2pc_commits(path):
    commits = []
    try:
        with open(path, 'rb') as f:
            for l in f:
                a = eval(l)
                if (a[1] == '2-ok') and (a[3] > 0):
                    logfile = get_logfile_path(path)
                    x = (a[0], a[3], logfile, a[2])
                    commits.append(x)
    except FileNotFoundError:
        []
    return commits

def get_logfile_path(txnlog_path):
    return txnlog_path[:-7] # remove ".txnlog"

def read_chunk(path, start_offset, end_offset):
    """
    Return only if 100% successful.
    """
    try:
        with open(path, 'r') as f:
            f.seek(start_offset)
            return f.read(end_offset - start_offset)
    except FileNotFoundError as e:
        raise e

commits = []
last_offset = {}
for f in sys.argv[1:]:
    logfile = get_logfile_path(f)
    last_offset[logfile] = 0
    for c in get_2pc_commits(f):
        commits.append(c)

concat_offset = 0
commits.sort()
for c in commits:
    (time, end_offset, path, txn_id_) = c
    chunk = read_chunk(path, last_offset[path], end_offset)
    sys.stdout.write(chunk)
    sys.stderr.write("{}\n".format((time, path, last_offset[path], end_offset, "to", concat_offset)))
    last_offset[path] = end_offset
    concat_offset = concat_offset + len(chunk)
