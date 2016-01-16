import sys
import os
import time
import subprocess
import re
import signal
from configparser import SafeConfigParser

PAUSE = 1

def print_buffy_node(in_ip, out_ip):
    print("dagon: Creating BUFFY node " + in_ip + " --> " + out_ip)

def print_spike_node(in_ip, out_ip, action):
    print("dagon: Creating SPIKE **" + action + "** node " + in_ip + " --> " + out_ip)


## CONFIGURE

# Parse command line args
config_filename = sys.argv[1] + ".ini"
duration = int(sys.argv[2])
if (len(sys.argv) > 3):
    seed = sys.argv[3]
else:
    seed = int(round(time.time() * 1000))


# Get config info
parser = SafeConfigParser()
parser.read(config_filename)

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


## RUN TOPOLOGY

processes = [] # A list of spawned subprocesses
devnull = open(os.devnull, "w") # For suppressing stdout/stderr of subprocesses
giles_output = open("dagon.giles", "w")
giles_output.seek(0)
giles_output.truncate()
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
print("dagon: Creating GILES node writing to source and listening at sink")
processes.append(subprocess.Popen(["../giles/giles", source_addr[0], source_addr[1], sink_addr[0], sink_addr[1]], stdout=giles_output, stderr=giles_output))
print("dagon: Test is running...")

# Let test run for duration
time.sleep(duration)
print("dagon: Finished")

# Kill subprocesses
for process in processes:
    os.kill(process.pid, signal.SIGTERM)


## CALCULATE TEST RESULTS

badline_count = 0
giles_output.close()
giles_output = open("dagon.giles", "r")
for line in giles_output.readlines():
    if re.search("bad message", line):
        badline_count += 1

test_result = "PASSED" if badline_count == 0 else "FAILED"
print("dagon: Test has " + test_result)
if test_result == "FAILED":
    print("dagon: Bad messages = " + str(badline_count))


## CLEAN UP

giles_output.close()
devnull.close()
sys.exit()