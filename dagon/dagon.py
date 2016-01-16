import sys
import os
import time
import subprocess
import re
import signal
from configparser import SafeConfigParser

PAUSE = 0.25

parser = SafeConfigParser()
parser.read("dagon.ini")

# Parse command line args
duration = int(sys.argv[1])
if (len(sys.argv) > 2):
    seed = sys.argv[2]
else:
    seed = int(round(time.time() * 1000))

# Get config info
nodes = {}
for section in parser.sections():
    if section == "edges": continue
    nodes[section] = {}
    options = parser.options(section)
    for option in options:
        nodes[section][option] = parser.get(section, option)

edges = []
origins = parser.options("edges")
for origin in origins:
    target = parser.get("edges", origin)
    edges.append((origin, target))

## This won't work for non-pipeline topologies until worker.py can have multiple outputs

processes = []
devnull = open(os.devnull, "w")
results = open("dagon.results", "w")
results.seek(0)
results.truncate()

def print_buffy_node(in_ip, out_ip):
    print("dagon: Creating buffy node " + in_ip + " --> " + out_ip)

def print_spike_node(in_ip, out_ip, action):
    print("dagon: Creating " + action + " spike node " + in_ip + " --> " + out_ip)


print("dagon: Creating topology...")

# Set up origin
origin_node = edges[0][0]
origin_in_ip = nodes[origin_node]["in_ip"]
origin_out_ip = nodes[origin_node]["out_ip"]
print_buffy_node(origin_in_ip, origin_out_ip)
processes.append(subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", origin_in_ip], stdout=devnull, stderr=devnull))
time.sleep(PAUSE)
processes.append(subprocess.Popen(["python3.5", "../buffy/worker.py", origin_in_ip, origin_out_ip], stdout=devnull, stderr=devnull))
time.sleep(PAUSE)

# Set up targets
for f,t in edges:
    action = nodes[f]["d"]
    f_in_ip = nodes[f]["in_ip"]
    f_out_ip = nodes[f]["out_ip"]
    t_in_ip = nodes[t]["in_ip"]
    t_out_ip = nodes[t]["out_ip"]
    print_spike_node(f_out_ip, t_in_ip, action)
    processes.append(subprocess.Popen(["../spike/spike", f_out_ip, t_in_ip, action, str(seed)], stdout=devnull, stderr=devnull))
    print_buffy_node(t_in_ip, t_out_ip)
    processes.append(subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", t_in_ip], stdout=devnull, stderr=devnull))
    time.sleep(PAUSE)
    processes.append(subprocess.Popen(["python3.5", "../buffy/worker.py", t_in_ip, t_out_ip], stdout=devnull, stderr=devnull))
    time.sleep(PAUSE)

source_addr = nodes[edges[0][0]]["in_ip"].split(":")
sink_addr = nodes[edges[len(edges) - 1][1]]["out_ip"].split(":")
print("dagon: Source is " + source_addr[0] + ":" + source_addr[1])
print("dagon: Sink is " + sink_addr[0] + ":" + sink_addr[1])

# Set up testing framework
print("dagon: Creating giles node writing to source and listening at sink")
processes.append(subprocess.Popen(["../giles/giles", source_addr[0], source_addr[1], sink_addr[0], sink_addr[1]], stdout=results))


print("dagon: Test is running...")

time.sleep(duration)
print("dagon: Finished")

for process in processes:
    os.kill(process.pid, signal.SIGTERM)

badline_count = 0
results.close()
results = open("dagon.results", "r")
for line in results.readlines():
    if re.search("bad message", line):
        badline_count += 1

test_result = "PASSED" if badline_count == 0 else "FAILED"
print("dagon: Test has " + test_result)
if test_result == "FAILED":
    print("dagon: Bad messages = " + str(badline_count))

results.close()
devnull.close()
sys.exit()