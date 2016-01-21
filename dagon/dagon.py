import click
import sys
import os
import time
import subprocess
import signal
import socket
from configparser import SafeConfigParser

LOCAL_ADDR = "127.0.0.1"
PAUSE = 1
CONFIG_FILENAME = ""
DURATION = 0
SEED = 0
INFINITE = False
NODE_DEFAULTS = {
    "d": "pass",
    "p": "10"
}

def print_buffy_node(in_ip, out_ip):
    print("dagon: Creating BUFFY node " + in_ip + " --> " + out_ip)

def print_spike_node(in_ip, out_ip, action):
    print("dagon: Creating SPIKE **" + action + "** node " + in_ip + " --> " + out_ip)

def print_instructions_and_exit():
    print("USAGE: python3.5 dagon.py topology-name duration [seed]")
    sys.exit()

def find_unused_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('localhost', 0))
    addr, port = s.getsockname()
    s.close()
    return LOCAL_ADDR + ":" + str(port)

def populate_node_lookup(node_names):
    lookup = {}
    count = 0
    for name in node_names:
        if name == "edges": continue
        lookup[name] = count
        count += 1
    return lookup

def populate_reverse_lookup(node_lookup):
    reverse_lookup = {}
    for key,value in node_lookup.items():
        reverse_lookup[value] = key
    return reverse_lookup

class Graph:
    def __init__(self, node_count):
        self.node_count = node_count
        self.es = []
        for i in range(node_count):
            self.es.append([])

    def add_edge(self, origin, target):
        if target not in self.es[origin]:
            self.es[origin].append(target)

    def sinks(self):
        sinks = []
        for i in range(self.node_count):
            if len(self.es[i]) == 0:
                sinks.append(i)
        return sinks

    def sources(self):
        converse = Graph(self.node_count)
        for i in range(self.node_count):
            for target in self.es[i]:
                converse.add_edge(target, i)
        return converse.sinks()

## CONFIGURE

# Parse command line args
@click.command()
@click.argument("config_file")
@click.argument("duration")
@click.option("--seed", default=int(round(time.time() * 1000)), help="Random number seed")
def cli(config_file, duration, seed):
    CONFIG_FILENAME = config_file + ".ini"
    DURATION = int(duration)
    SEED = seed

    # Get config info
    parser = SafeConfigParser()
    parser.read(CONFIG_FILENAME)

    nodes = {}
    node_lookup = populate_node_lookup(parser.sections())
    reverse_lookup = populate_reverse_lookup(node_lookup)
    for section in parser.sections():
        if section == "edges": continue
        nodes[section] = NODE_DEFAULTS
        options = parser.options(section)
        for option in options:
            nodes[section][option] = parser.get(section, option)

    graph = Graph(len(nodes))
    edges = []
    origins = parser.options("edges")
    for origin in origins:
        if origin not in node_lookup:
            print(origin + " must be specified as [" + origin + "] in the .ini file")
            sys.exit()
        target = parser.get("edges", origin)
        if target not in node_lookup:
            print(target + " must be specified as [" + target + "] in the .ini file")
            sys.exit()
        graph.add_edge(node_lookup[origin], node_lookup[target])
        edges.append((origin, target))


    sources = graph.sources()
    if len(sources) > 1:
        print("A topology can only have one source!")
        sys.exit()
    if len(sources) == 0:
        print("A topology must have a source!")
        sys.exit()
    source = sources[0]
    sinks = graph.sinks()
    if len(sinks) > 1:
        print("A topology can only have one sink!")
        sys.exit()
    if len(sinks) == 0:
        print("A topology must have a sink!")
        sys.exit()
    sink = sinks[0]


    ## RUN TOPOLOGY

    processes = [] # A list of spawned subprocesses
    devnull = open(os.devnull, "w") # For suppressing stdout/stderr of subprocesses
    giles_output = open("dagon.giles", "w")
    giles_output.seek(0)
    giles_output.truncate()
    print("dagon: Creating topology with seed " + str(seed) + "...")

    # Set up origin
    origin_node = edges[0][0]
    nodes[origin_node]["in_ip"] = find_unused_port()
    origin_in_ip = nodes[origin_node]["in_ip"]
    nodes[origin_node]["out_ip"] = find_unused_port()
    origin_out_ip = nodes[origin_node]["out_ip"]
    print_buffy_node(origin_in_ip, origin_out_ip)
    processes.append(subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", origin_in_ip], stdout=devnull, stderr=devnull))
    time.sleep(PAUSE)
    processes.append(subprocess.Popen(["python3.5", "../buffy/worker.py", origin_in_ip, origin_out_ip], stdout=devnull, stderr=devnull))
    time.sleep(PAUSE)

    # Set up targets
    for f,t in edges:
        action = nodes[f]["d"]
        probability = nodes[f]["p"]
        f_out_ip = nodes[f]["out_ip"]
        nodes[t]["in_ip"] = find_unused_port()
        t_in_ip = nodes[t]["in_ip"]
        nodes[t]["out_ip"] = find_unused_port()
        t_out_ip = nodes[t]["out_ip"]
        print_spike_node(f_out_ip, t_in_ip, action)
        processes.append(subprocess.Popen(["../spike/spike", f_out_ip, t_in_ip, action, "--seed",  str(SEED), "--prob", probability], stdout=devnull, stderr=devnull))
        print_buffy_node(t_in_ip, t_out_ip)
        processes.append(subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", t_in_ip], stdout=devnull, stderr=devnull))
        time.sleep(PAUSE)
        processes.append(subprocess.Popen(["python3.5", "../buffy/worker.py", t_in_ip, t_out_ip], stdout=devnull, stderr=devnull))
        time.sleep(PAUSE)

    source_addr = nodes[reverse_lookup[source]]["in_ip"].split(":")
    sink_addr = nodes[reverse_lookup[sink]]["out_ip"].split(":")
    print("dagon: Source is " + source_addr[0] + ":" + source_addr[1])
    print("dagon: Sink is " + sink_addr[0] + ":" + sink_addr[1])

    # Set up testing framework
    print("dagon: Creating GILES node writing to source and listening at sink")
    processes.append(subprocess.Popen(["../giles/giles", source_addr[0], source_addr[1], sink_addr[0], sink_addr[1]], stdout=giles_output, stderr=giles_output))
    print("dagon: Test is running...")

    # Let test run for duration
    time.sleep(DURATION)
    print("dagon: Finished")

    # Kill subprocesses
    for process in processes:
        os.kill(process.pid, signal.SIGTERM)
    time.sleep(5)

    ## CALCULATE TEST RESULTS

    diff_proc = subprocess.Popen(["diff", "--brief", "sent.txt", "received.txt"], stdout=subprocess.PIPE)
    diff = diff_proc.stdout.read()

    test_result = "PASSED" if diff == "" else "FAILED"
    print("\ndagon: Test has " + test_result)

    ## CLEAN UP

    giles_output.close()
    devnull.close()
    sys.exit()


if __name__ == '__main__':
    cli()
