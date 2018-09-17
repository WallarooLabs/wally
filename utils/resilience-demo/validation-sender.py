
from end_points import (
						 Reader,
						 sequence_generator
	)
from integration import (
						 Sender
	)

import sys
import time

wallaroo_hostsvc = sys.argv[1]
num_start = int(sys.argv[2])
num_end   = int(sys.argv[3])
batch_size = int(sys.argv[4])
interval = float(sys.argv[5])
num_part_keys = int(sys.argv[6])

senders = []
for p in range(0, num_part_keys):
	sender = Sender(wallaroo_hostsvc,
					Reader(sequence_generator(start=num_start, stop=num_end,
											  partition='key_%d' % p)),
                	batch_size=batch_size, interval=interval, reconnect=True)
	senders.append(sender)

for s in senders:
	s.start()
for s in senders:
	s.join()

sys.exit(0)