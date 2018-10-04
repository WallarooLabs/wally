#!/usr/bin/env python2
"""
validate.py N_WORKERS N_INPUT_ITEMS OUTPUTFILE
"""
import sys
n_workers = int(sys.argv[1])
n_input_items = int(sys.argv[2])
output_file = open(sys.argv[3])

decoded = filter(lambda x: x!='',
                 "".join(output_file.readlines()).split("\x00"))
ids_pids = map(lambda x: x.split(":"), decoded)
n_output_ids = len(map(lambda x: x[0], ids_pids))
pids = map(lambda x: x[1], ids_pids)

unique_pids = len(set(pids))

if (n_input_items == n_output_ids) and (unique_pids == n_workers):
    sys.exit(0)
else:
    print "Expected {} pids, {} items".format(n_workers, n_input_items)
    print "GOT {} pids, {} items".format(unique_pids, n_output_ids)
    sys.exit(1)
