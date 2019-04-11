#!/usr/bin/env python2
"""
validate.py N_WORKERS N_INPUT_ITEMS OUTPUTFILE
"""
import sys
n_workers = int(sys.argv[1])
n_input_items = int(sys.argv[2])
output_file = open(sys.argv[3])

decoded = list(filter(lambda x: x!='',
                 "".join(output_file.readlines()).split("\x00")))
ids_pids = [ item.split(":") for item in decoded ]
n_output_ids = len([ id_pid[0] for id_pid in ids_pids ])
n_worker_pids = len(set([ id_pid[1] for id_pid in ids_pids ]))

if (n_input_items == n_output_ids) and (n_worker_pids == n_workers):
    sys.exit(0)
else:
    print "Expected {} pids, {} items".format(n_workers, n_input_items)
    print "GOT {} pids, {} items".format(n_worker_pids, n_output_ids)
    sys.exit(1)
