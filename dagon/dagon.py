#!/usr/bin/env python3

import click
import sys
import os
import time
import subprocess
import signal
import socket
import imp
import giles_parser as gilesParser
import metrics
from configparser import SafeConfigParser

import dotgen

LOCAL_ADDR = '127.0.0.1'
PAUSE = 1
DEVNULL = open(os.devnull, 'w') # For suppressing stdout/stderr of subprocesses


def node_defaults():
    return {
        'd': 'pass',
        'p': '10',
        'f': 'passthrough'
    }

def remove_file(filename):
    try:
        os.remove(filename)
    except OSError:
        pass

def print_buffy_node(func, in_ip, out_ip):
    print('dagon: Creating BUFFY #' + func + '# node ' + in_ip + ' -> ' + out_ip)

def print_spike_node(action, probability, in_ip, out_ip):
    print('dagon: Creating SPIKE **' + action + ' (' + probability + '%)** node ' + in_ip + ' -> ' + out_ip)

def print_instructions_and_exit():
    print('USAGE: python3 dagon.py topology-name duration [--seed seed]')
    sys.exit()

def print_mismatch(sent, rcvd):
    sent = '*nothing*' if sent == '' else sent
    rcvd = '*nothing*' if rcvd == '' else rcvd
    print('\nStopped at mismatch:')
    print('SENT: ' + sent)
    print('RCVD: ' + rcvd)

def find_unused_port():
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.bind(("localhost", 0))
    addr, port = s.getsockname()
    s.close()
    return LOCAL_ADDR + ':' + str(port)

def populate_node_options(parser, topology, lookup):
    for section in parser.sections():
        if section == 'edges': continue
        node_id = lookup[section]
        topology.update_node(node_id, 'name', section)
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
    origins = parser.options('edges')
    for origin in origins:
        if origin not in lookup:
            print(origin + ' must be specified as [' + origin + '] in the .ini file')
            sys.exit()
        target = parser.get('edges', origin)
        if target not in lookup:
            print(target + ' must be specified as [' + target + '] in the .ini file')
            sys.exit()
        topology.add_edge(lookup[origin], lookup[target])

def start_spike_process(f_out_ip, t_in_ip, seed, action, probability):
    print_spike_node(action, probability, f_out_ip, t_in_ip)
    spike = subprocess.Popen(['../spike/spike', f_out_ip, t_in_ip, action, '--seed',  str(seed), '--prob', probability], stdout=DEVNULL, stderr=DEVNULL)
    return spike

def start_buffy_processes(f, in_addr, out_addr, is_sink):
    processes = []
    print_buffy_node(f, in_addr, out_addr)
    output_type = 'socket' if is_sink else 'queue'
    processes.append(subprocess.Popen(['python3', '../buffy/MQ_udp.py', '--address', in_addr], stdout=DEVNULL, stderr=DEVNULL))
    time.sleep(PAUSE)
    processes.append(subprocess.Popen(['python3', '../buffy/worker.py', '--input-address', in_addr, '--output-address', out_addr, '--function', f, '--output-type', output_type], stdout=DEVNULL, stderr=DEVNULL))
    time.sleep(PAUSE)
    return processes

def start_giles_sender_process(source_addr, test):
    remove_file('sent.txt')

    print('dagon: Creating GILES-SENDER node writing to source')
    giles_sender = subprocess.Popen(['../giles/sender/sender', source_addr], stdout=DEVNULL, stderr=DEVNULL)
    print('-----------------------------------------------------------------------')
    print('dagon: Test <<' + test + '>> is running...')
    return giles_sender

def start_giles_receiver_process(sink_addr):
    remove_file('received.txt')

    print('dagon: Creating GILES-RECEIVER node listening at sink')
    giles_receiver = subprocess.Popen(['../giles/receiver/receiver', sink_addr], stdout=DEVNULL, stderr=DEVNULL)
    return giles_receiver

def start_nodes(topo, seed):
    processes = []
    for n in range(topo.size()):
        topo.update_node(n, 'in_addr', find_unused_port())
        topo.update_node(n, 'out_addr', find_unused_port())

    for n in range(topo.size()):
        func = topo.get_node_option(n, 'f')
        n_in_addr = topo.get_node_option(n, 'in_addr')
        n_out_addr = topo.get_node_option(n, 'out_addr')

        for i in topo.inputs_for(n):
            action = topo.get_node_option(i, 'd')
            probability = topo.get_node_option(i, 'p')
            i_out_addr = topo.get_node_option(i, 'out_addr')
            processes.append(start_spike_process(i_out_addr, n_in_addr, seed, action, probability))

        if n == topo.sink():
            processes += start_buffy_processes(func, n_in_addr, n_out_addr, True)
        else:
            processes += start_buffy_processes(func, n_in_addr, n_out_addr, False)
    return processes

def calculate_test_results(test, expect_mismatch, display_metrics):
    success_predicate = load_func('./config/' + test + '.py')
    # If we expect a mismatch, then the starting value for passes is
    # false. On discovering a mismatch this value is toggled.
    passes = True if not expect_mismatch else False
    sent = []
    rcvd = []

    with open("sent.txt") as sent_file, open("received.txt") as rcvd_file:
        sent = gilesParser.records_for(sent_file)
        rcvd = gilesParser.records_for(rcvd_file)
        s_len = len(sent)
        r_len = len(rcvd)

        for i in range(min(s_len, r_len)):
            s = sent[i]['payload']
            r = rcvd[i]['payload']
            try:
                line_passes = success_predicate(s, r) if (s != '') else (r == '')
            except:
                print("\nTest predicate error. Payload might have been garbled. Check your test function.")
                passes = not passes
                break
            if not line_passes:
                print_mismatch(s, r)
                passes = not passes
                break

        if passes != expect_mismatch:
            if r_len > s_len:
                s = ''
                r = rcvd[s_len]['payload']
                print_mismatch(s, r)
                passes = not passes
            elif s_len > r_len:
                s = sent[r_len]['payload']
                r = ''
                print_mismatch(s, r)
                passes = not passes

    test_result = 'PASSED' if passes else 'FAILED'
    if expect_mismatch:
        found = 'at least one' if passes else 'none'
        print('\ndagon: Expected mismatch. Found ' + found + '.')
    else:
        found = 'none' if passes else 'at least one'
        print('\ndagon: Expected no mismatches. Found ' + found + '.')

    print('dagon: Test has ' + test_result)
    if display_metrics and passes and not expect_mismatch:
        metrics.print_throughput(rcvd)
        metrics.print_latency_histogram(sent, rcvd)

class Topology:
    def __init__(self, name, node_count):
        self.name = name
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
            print('A topology can only have one source!')
            sys.exit()
        if len(sources) == 0:
            print('A topology must have a source!')
            sys.exit()
        return sources[0]

    def sink(self):
        sinks = self._sinks()
        if len(sinks) > 1:
            print('A topology can only have one sink!')
            sys.exit()
        if len(sinks) == 0:
            print('A topology must have a sink!')
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


def load_func(filename, funcname="func"):
    _m = imp.load_source("_m", filename)
    return getattr(_m, funcname)

## CONFIGURE

# Parse command line args
@click.command()
@click.argument('topology_name')
@click.option('--gendot', is_flag=True, default=False)
@click.option('--duration', default=3, help='Pseudo-random number seed')
@click.option('--seed', default=int(round(time.time() * 1000)), help='Pseudo-random number seed')
@click.option('--test', default='identity', help='Name of condition for passing test')
@click.option('--mismatch', is_flag=True, default=False, help='Signifies that we expect a mismatch.')
@click.option('--metrics', is_flag=True, default=False, help='Print throughput and latency metrics.')
def cli(topology_name, gendot, duration, seed, test, mismatch, metrics):
    processes = [] # A list of spawned subprocesses
    duration = int(duration)
    config_filename = './config/' + topology_name + '.ini'

    # Get config info
    parser = SafeConfigParser()
    parser.read(config_filename)

    # Set up topology
    node_names = list(filter(lambda n: n != 'edges', parser.sections()))
    topology = Topology(topology_name, len(node_names))

    node_lookup = populate_node_lookup(node_names)
    populate_node_options(parser, topology, node_lookup)
    populate_edges(parser, topology, node_lookup)

    if gendot:
        dotgen.generate_dotfile(topology)
        return

    ## RUN TOPOLOGY

    print('-----------------------------------------------------------------------')
    print('*DAGON* Creating topology "' + topology_name + '" with seed ' + str(seed) + '...')
    print('-----------------------------------------------------------------------')

    # Start topology
    topology_processes = start_nodes(topology, seed)
    processes += topology_processes

    source_addr = topology.get_node_option(topology.source(), 'in_addr')
    print('dagon: Source is ' + source_addr)
    sink_addr = topology.get_node_option(topology.sink(), 'out_addr')
    print('dagon: Sink is ' + sink_addr)

    giles_receiver_process = start_giles_receiver_process(sink_addr)
    time.sleep(1)
    giles_sender_process = start_giles_sender_process(source_addr, test)

    # Let test run for duration
    time.sleep(duration)
    print('dagon: Finished')

    # Tell giles-sender to stop sending messages
    os.kill(giles_sender_process.pid, signal.SIGTERM)
    time.sleep(5)

    # Tell giles-receiver to shutdown
    os.kill(giles_receiver_process.pid, signal.SIGTERM)

    # Kill subprocesses
    for process in processes:
        os.kill(process.pid, signal.SIGTERM)
    time.sleep(5)


    ## CALCULATE TEST RESULTS
    calculate_test_results(test, mismatch, metrics)


    ## CLEAN UP
    DEVNULL.close()
    sys.exit()


if __name__ == "__main__":
    cli()
