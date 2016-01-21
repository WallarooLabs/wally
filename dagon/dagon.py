import click
import sys
import os
import time
import subprocess
import re
import signal
from configparser import SafeConfigParser

PAUSE = 1
CONFIG_FILENAME = ""
DURATION = 0
SEED = 0
INFINITE = False

def print_buffy_node(in_ip, out_ip):
    print("dagon: Creating BUFFY node " + in_ip + " --> " + out_ip)

def print_spike_node(in_ip, out_ip, action):
    print("dagon: Creating SPIKE **" + action + "** node " + in_ip + " --> " + out_ip)

def print_instructions_and_exit():
    print("USAGE: python3.5 dagon.py topology-name duration [seed]")
    sys.exit()

## CONFIGURE

# Parse command line args
@click.command()
@click.argument("config_file")
@click.argument("duration")
@click.option("--seed", default=int(round(time.time() * 1000)), help="Random number seed")
@click.option("--infinite", is_flag=True)
def cli(config_file, duration, seed, infinite):
    CONFIG_FILENAME = config_file + ".ini"
    DURATION = int(duration)
    SEED = seed
    INFINITE = infinite

    # Get config info
    parser = SafeConfigParser()
    parser.read(CONFIG_FILENAME)

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
        processes.append(subprocess.Popen(["../spike/spike", f_out_ip, t_in_ip, action, str(SEED)], stdout=devnull, stderr=devnull))
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
