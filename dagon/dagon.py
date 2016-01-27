import click
import sys
import os
import time
import subprocess
import signal
import socket
import imp
import itertools
from configparser import SafeConfigParser


LOCAL_ADDR = "127.0.0.1"
PAUSE = 1
DEVNULL = open(os.devnull, "w") # For suppressing stdout/stderr of subprocesses


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

def print_buffy_node(func, in_ip, out_ip):
    print("dagon: Creating BUFFY #" + func + "# node " + in_ip + " --> " + out_ip)

def print_spike_node(action, in_ip, out_ip):
    print("dagon: Creating SPIKE **" + action + "** node " + in_ip + " --> " + out_ip)

def print_instructions_and_exit():
    print("USAGE: python3.5 dagon.py topology-name duration [--seed seed]")
    sys.exit()

def find_unused_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(('localhost', 0))
    addr, port = s.getsockname()
    s.close()
    return LOCAL_ADDR + ":" + str(port)

def populate_node_options(parser, topology, lookup):
    for section in parser.sections():
        if section == "edges": continue
        node_id = lookup[section]
        options = parser.options(section)
        for option in options:
            option_val = parser.get(section, option)
            topology.update_node(node_id, option, option_val)

def populate_node_lookup(node_names):
    lookup = {}
    count = 0
    for name in node_names:
        lookup[name] = count
        count += 1
    return lookup

def populate_edges(parser, topology, lookup):
    origins = parser.options("edges")
    for origin in origins:
        if origin not in lookup:
            print(origin + " must be specified as [" + origin + "] in the .ini file")
            sys.exit()
        target = parser.get("edges", origin)
        if target not in lookup:
            print(target + " must be specified as [" + target + "] in the .ini file")
            sys.exit()
        topology.add_edge(lookup[origin], lookup[target])

def start_spike_process(f_out_ip, t_in_ip, seed, action, probability):
    print_spike_node(action, f_out_ip, t_in_ip)
    spike = subprocess.Popen(["../spike/spike", f_out_ip, t_in_ip, action, "--seed",  str(seed), "--prob", probability], stdout=DEVNULL, stderr=DEVNULL)
    return spike

def start_buffy_processes(f, in_addr, out_addr, is_sink):
    processes = []
    print_buffy_node(f, in_addr, out_addr)
    output_type = "socket" if is_sink else "queue"
    processes.append(subprocess.Popen(["python3.5", "../buffy/MQ_udp.py", in_addr], stdout=DEVNULL, stderr=DEVNULL))
    time.sleep(PAUSE)
    processes.append(subprocess.Popen(["python3.5", "../buffy/worker.py", "--input-address", in_addr, "--output-address", out_addr, "--function", f, "--output-type", output_type], stdout=DEVNULL, stderr=DEVNULL))
    time.sleep(PAUSE)
    return processes

def start_giles_process(topology, test):
    source_addr = topology.get_node_option(topology.source(), "in_addr")
    print("dagon: Source is " + source_addr)
    sink_addr = topology.get_node_option(topology.sink(), "out_addr")
    print("dagon: Sink is " + sink_addr)

    remove_file("sent.txt")
    remove_file("received.txt")

    print("dagon: Creating GILES node writing to source and listening at sink")
    giles = subprocess.Popen(["../giles/giles", source_addr, sink_addr], stdout=DEVNULL, stderr=DEVNULL)
    print("-----------------------------------------------------------------------")
    print("dagon: Test <<" + test + ">> is running...")
    return giles

def start_nodes(topo, seed):
    processes = []
    for n in range(topo.size()):
        topo.update_node(n, "in_addr", find_unused_port())
        topo.update_node(n, "out_addr", find_unused_port())

    for n in range(topo.size()):
        func = topo.get_node_option(n, "f")
        n_in_addr = topo.get_node_option(n, "in_addr")
        n_out_addr = topo.get_node_option(n, "out_addr")

        if n == topo.sink():
            processes += start_buffy_processes(func, n_in_addr, n_out_addr, True)
        else:
            processes += start_buffy_processes(func, n_in_addr, n_out_addr, False)

        for i in topo.inputs_for(n):
            action = topo.get_node_option(i, "d")
            probability = topo.get_node_option(i, "p")
            i_out_addr = topo.get_node_option(i, "out_addr")
            processes.append(start_spike_process(i_out_addr, n_in_addr, seed, action, probability))
    return processes

def calculate_test_results(test):
    success_predicate = load_func("./config/" + test + ".py")
    test_result = "PASSED"


    with open('sent.txt') as sent, open('received.txt') as rcvd:
        for next_sent, next_rcvd in itertools.zip_longest(sent, rcvd, fillvalue=""):
            s = next_sent.strip("\n")
            r = next_rcvd.strip("\n")
            line_passes = success_predicate(s, r) if (s != "") else (r == "")
            if not line_passes:
                print("\nTest fails on SENT: " + s + "; RCVD: " + r)
                test_result = "FAILED"
                break

    print("\ndagon: Test has " + test_result)



class Topology:
    def __init__(self, node_count):
        self._size = node_count
        self.out_es = []
        self.in_es = []
        self.nodes = []
        for i in range(self._size):
            self.out_es.append([])
            self.in_es.append([])
            self.nodes.append(node_defaults())

    def add_edge(self, origin, target):
        if target not in self.out_es[origin]:
            self.out_es[origin].append(target)
            self.in_es[target].append(origin)

    def update_node(self, n, key, val):
        self.nodes[n][key] = val

    def get_node_option(self, n, key):
        return self.nodes[n][key]

    def outputs_for(self, n):
        return self.out_es[n]

    def inputs_for(self, n):
        return self.in_es[n]

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
        for i in range(self._size):
            if len(self.out_es[i]) == 0:
                sinks.append(i)
        return sinks

    def _sources(self):
        sinks = []
        for i in range(self._size):
            if len(self.in_es[i]) == 0:
                sinks.append(i)
        return sinks

    def size(self):
        return self._size


def load_func(filename, funcname='func'):
    _m = imp.load_source('_m', filename)
    return getattr(_m, funcname)

## CONFIGURE

# Parse command line args
@click.command()
@click.argument("topology_name")
@click.argument("duration")
@click.option("--seed", default=int(round(time.time() * 1000)), help="Pseudo-random number seed")
@click.option("--test", default="identity", help="Name of condition for passing test")
def cli(topology_name, duration, seed, test):

    processes = [] # A list of spawned subprocesses
    config_filename = "./config/" + topology_name + ".ini"
    duration = int(duration)

    # Get config info
    parser = SafeConfigParser()
    parser.read(config_filename)

    # Set up topology
    node_names = list(filter(lambda n: n != "edges", parser.sections()))
    topology = Topology(len(node_names))

    node_lookup = populate_node_lookup(node_names)
    populate_node_options(parser, topology, node_lookup)
    populate_edges(parser, topology, node_lookup)

    ## RUN TOPOLOGY

    print("-----------------------------------------------------------------------")
    print("*DAGON* Creating topology '" + topology_name + "' with seed " + str(seed) + "...")
    print("-----------------------------------------------------------------------")

    # Start topology
    topology_processes = start_nodes(topology, seed)
    processes += topology_processes

    giles_process = start_giles_process(topology, test)
    processes.append(giles_process)

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
    calculate_test_results(test)


    ## CLEAN UP
    DEVNULL.close()
    sys.exit()


if __name__ == '__main__':
    cli()
