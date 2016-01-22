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
DEVNULL = open(os.devnull, "w") # For suppressing stdout/stderr of subprocesses
processes = [] # A list of spawned subprocesses


def node_defaults():
    return {
        "d": "pass",
        "p": "10"
    }

def remove_file(filename):
    try:
        os.remove(filename)
    except OSError:
        pass

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

def populate_node_options(parser):
    nodes = {}
    print(parser.sections())
    for section in parser.sections():
        if section == "edges": continue
        nodes[section] = node_defaults()
        options = parser.options(section)
        for option in options:
            nodes[section][option] = parser.get(section, option)
    return nodes

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

def start_spike_process(f_out_ip, t_in_ip, seed, action, probability):
    print_spike_node(f_out_ip, t_in_ip, action)
    processes.append(subprocess.Popen(["../spike/spike", f_out_ip, t_in_ip, action, "--seed",  str(seed), "--prob", probability], stdout=DEVNULL, stderr=DEVNULL))

def start_buffy_process(in_addr, out_addr):
    print_buffy_node(in_addr, out_addr)
    processes.append(subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", in_addr], stdout=DEVNULL, stderr=DEVNULL))
    time.sleep(PAUSE)
    processes.append(subprocess.Popen(["python3.5", "../buffy/worker.py", in_addr, out_addr], stdout=DEVNULL, stderr=DEVNULL))
    time.sleep(PAUSE)

def start_giles_process(source_addr, sink_addr):
    remove_file("sent.txt")
    remove_file("received.txt")

    print("dagon: Creating GILES node writing to source and listening at sink")
    giles = subprocess.Popen(["../giles/giles", source_addr[0], source_addr[1], sink_addr[0], sink_addr[1]], stdout=DEVNULL, stderr=DEVNULL)
    processes.append(giles)
    print("-----------------------------------------------------------------------")
    print("dagon: Test is running...")
    return giles

def start_processes_for(nodes, edge_pairs, seed):
    for f,t in edge_pairs:
        action = nodes[f]["d"]
        probability = nodes[f]["p"]
        f_out_ip = nodes[f]["out_ip"]
        nodes[t]["in_ip"] = find_unused_port()
        t_in_ip = nodes[t]["in_ip"]
        nodes[t]["out_ip"] = find_unused_port()
        t_out_ip = nodes[t]["out_ip"]

        start_spike_process(f_out_ip, t_in_ip, seed, action, probability)
        start_buffy_process(t_in_ip, t_out_ip)

def calculate_test_results():
    diff_proc = subprocess.Popen(["diff", "--brief", "sent.txt", "received.txt"], stdout=subprocess.PIPE)
    diff = diff_proc.stdout.read()

    print(diff)
    test_result = "PASSED" if diff == "" else "FAILED"
    print("\ndagon: Test has " + test_result)


class Graph:
    def __init__(self, node_count):
        self.node_count = node_count
        self.es = []
        for i in range(node_count):
            self.es.append([])

    def add_edge(self, origin, target):
        if target not in self.es[origin]:
            self.es[origin].append(target)

    def source(self):
        sources = self._sources()
        if len(sources) > 1:
            print("A topology can only have one source!")
            sys.exit()
        if len(sources) == 0:
            print("A topology must have a source!")
            sys.exit()
        return sources[0]

    def sink(self):
        sinks = self._sinks()
        if len(sinks) > 1:
            print("A topology can only have one sink!")
            sys.exit()
        if len(sinks) == 0:
            print("A topology must have a sink!")
            sys.exit()
        return sinks[0]

    def _sinks(self):
        sinks = []
        for i in range(self.node_count):
            if len(self.es[i]) == 0:
                sinks.append(i)
        return sinks

    def _sources(self):
        converse = Graph(self.node_count)
        for i in range(self.node_count):
            for target in self.es[i]:
                converse.add_edge(target, i)
        return converse._sinks()

## CONFIGURE

# Parse command line args
@click.command()
@click.argument("topology_name")
@click.argument("duration")
@click.option("--seed", default=int(round(time.time() * 1000)), help="Random number seed")
def cli(topology_name, duration, seed):
    config_filename = topology_name + ".ini"
    duration = int(duration)

    # Get config info
    parser = SafeConfigParser()
    parser.read(config_filename)

    nodes = populate_node_options(parser)
    node_lookup = populate_node_lookup(parser.sections())
    reverse_lookup = populate_reverse_lookup(node_lookup)

    # Set up graph and edge_pairs
    graph = Graph(len(nodes))
    edge_pairs = []
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
        edge_pairs.append((origin, target))

    source = graph.source()
    sink = graph.sink()


    ## RUN TOPOLOGY

    print("-----------------------------------------------------------------------")
    print("*DAGON* Creating topology '" + topology_name + "' with seed " + str(seed) + "...")
    print("-----------------------------------------------------------------------")

    # Set up origin
    origin_node = reverse_lookup[source]
    nodes[origin_node]["in_ip"] = find_unused_port()
    origin_in_ip = nodes[origin_node]["in_ip"]
    nodes[origin_node]["out_ip"] = find_unused_port()
    origin_out_ip = nodes[origin_node]["out_ip"]

    start_buffy_process(origin_in_ip, origin_out_ip)

    # Set up rest of topology
    start_processes_for(nodes, edge_pairs, seed)

    source_addr = nodes[reverse_lookup[source]]["in_ip"].split(":")
    sink_addr = nodes[reverse_lookup[sink]]["out_ip"].split(":")
    print("dagon: Source is " + source_addr[0] + nodes[reverse_lookup[source]]["in_ip"])
    print("dagon: Sink is " + nodes[reverse_lookup[sink]]["out_ip"])

    giles_process = start_giles_process(source_addr, sink_addr)

    # Let test run for duration
    time.sleep(duration)
    print("dagon: Finished")

    # Tell giles to stop sending messages
    os.kill(giles_process.pid, signal.SIGUSR1)
    time.sleep(5)

    # Kill subprocesses
    for process in processes:
        os.kill(process.pid, signal.SIGTERM)
    time.sleep(5)


    ## CALCULATE TEST RESULTS
    calculate_test_results()


    ## CLEAN UP
    DEVNULL.close()
    sys.exit()


if __name__ == '__main__':
    cli()
