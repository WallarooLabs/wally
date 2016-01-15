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

## This won't work for non-pipeline topologies until worker.py can have multiple outputs

# Set up origin
origin_node = edges[0][0]
origin_in_ip = nodes[origin_node]["in_ip"]
origin_out_ip = nodes[origin_node]["out_ip"]
subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", origin_in_ip])
subprocess.Popen(["python3.5", "../buffy/worker.py", origin_in_ip, origin_out_ip])

# Set up targets
for from,to in edges:
    action = nodes[from]["d"]
    from_in_ip = nodes[from]["in_ip"]
    from_out_ip = nodes[from]["out_ip"]
    to_in_ip = nodes[to]["in_ip"]
    to_out_ip = nodes[to]["out_ip"]
    subprocess.Popen(["../spike/spike", from_out_ip, to_in_ip, action, str(seed)])
    subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", to_in_ip])
    subprocess.Popen(["python3.5", "../buffy/worker.py", to_in_ip, to_out_ip])

source_addr = nodes[edges[0][0]]["in_ip"].split(":")
sink_addr = nodes[edges[len(edges) - 1][1]]["out_ip"].split(":")

# Set up testing framework
subprocess.call(["../giles/giles", source_addr[0], source_addr[1], sink_addr[0], sink_addr[1]])
