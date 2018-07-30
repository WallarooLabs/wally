from collections import namedtuple
import os
import wallaroo
import time

N_PARTITIONS=4
NoneClass=namedtuple("NoneClass", [])

def application_setup(args):
    # wallaroo pipeline
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    tcp_source = wallaroo.TCPSourceConfig(in_host, in_port, decoder)
    tcp_sink = wallaroo.TCPSinkConfig(out_host, out_port, encoder)

    ab = wallaroo.ApplicationBuilder("Parallel stateless test app")
    ab.new_pipeline("Parallel test app", tcp_source)
    # Comment out to_stateful to see round-robin
    # Leave it in place to see no round-robin
    #ab.to_stateful(const, NoneClass, "whatever")
    ab.to(const_list)
    ab.to_parallel(report_executing_node),
    ab.to_sink(tcp_sink)
    return ab.build()

@wallaroo.state_computation(name="return the same thing")
def const(_a, _b):
    return (1, True)

@wallaroo.computation_multi(name="return a list")
def const_list(_):
    return [1,2,3,4]

@wallaroo.computation(name="Report which node got which record")
def report_executing_node(thing):
    report = "NODE pid: %s got chunk: %s\n"%(os.getpid(), thing)
    return report

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(_any):
    return 1

@wallaroo.encoder
def encoder(report):
    return report
