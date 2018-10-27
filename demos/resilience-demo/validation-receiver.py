
from end_points import (
						 Reader,
						 Sink,
						 sequence_generator
	)
from control import (
					 SinkAwaitValue
	)

import re
import struct
import sys
import time

sink_hostsvc = sys.argv[1]
expect = int(sys.argv[2])
num_part_keys = int(sys.argv[3])
timeout = float(sys.argv[4])
output_file = sys.argv[5]
(sink_host, sink_port) = sink_hostsvc.split(":")

of = open(output_file, 'w')

def extract_fun(got):
	of.write(got)
	of.flush()
	return re.sub('.*\(', '(', got)

await_values = []
for p in range(0, num_part_keys):
	last_value = '(key_{}.TraceID-1.TraceWindow-1,[{}])' \
		.format(p, ','.join((str(expect-v) for v in range(3,-1,-1))))
	await_values.append(last_value)
print("await_values = %s" % await_values)

sink = Sink(sink_host, int(sink_port), mode='framed')
sink.start()

t = SinkAwaitValue(sink, await_values, timeout, extract_fun)
t.start()
t.join()
if t.error:
    raise t.error

of.close()
sys.exit(0)
