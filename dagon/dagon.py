import sys
import time
import subprocess
from configparser import SafeConfigParser

parser = SafeConfigParser()
parser.read("dagon.ini")

# Parse command line args
duration = sys.argv[1]
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

# Set up nodes
## This won't work for non-pipeline topologies until worker.py can have multiple outputs
for origin,target in edges:
    action = nodes[origin]["d"]
    o_in_ip = nodes[origin]["in_ip"]
    o_out_ip = nodes[origin]["out_ip"]
    subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", o_in_ip])
    time.sleep(1)
    subprocess.Popen(["python3.5", "../buffy/worker.py", o_in_ip, o_out_ip])
    time.sleep(1)
    t_in_ip = nodes[target]["in_ip"]
    t_out_ip = nodes[target]["out_ip"]
    subprocess.Popen(["../spike/spike", o_out_ip, t_in_ip, action, str(seed)])
    subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", t_in_ip])
    time.sleep(1)
    subprocess.Popen(["python3.5", "../buffy/worker.py", t_in_ip, t_out_ip])
    time.sleep(1)

source_addr = nodes[edges[0][0]]["in_ip"].split(":")
sink_addr = nodes[edges[len(edges) - 1][1]]["out_ip"].split(":")

# Set up testing framework
subprocess.call(["../giles/giles", source_addr[0], source_addr[1], sink_addr[0], sink_addr[1]])
