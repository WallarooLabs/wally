from collections import namedtuple
import os
import wallaroo
import time

NoneClass=namedtuple("NoneClass", [])

def application_setup(args):
    # wallaroo pipeline
    in_host, in_port = wallaroo.tcp_parse_input_addrs(args)[0]
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]
    tcp_source = wallaroo.TCPSourceConfig(in_host, in_port, decoder)
    tcp_sink = wallaroo.TCPSinkConfig(out_host, out_port, encoder)

    ab = wallaroo.ApplicationBuilder("Parallel stateless test app")
    ab.new_pipeline("Parallel test app", tcp_source)
    ab.to(multiplex)
    ab.to_parallel(factorial),
    ab.to_sink(tcp_sink)
    return ab.build()

@wallaroo.computation_multi(name="return a list")
def multiplex(n):
    lot_of_work = n*10000
    return [lot_of_work, lot_of_work, lot_of_work, lot_of_work]

@wallaroo.computation(name="factorial function")
def factorial(n):
    start_time = time.time()
    _ = factorial_(n)
    end_time = time.time()
    report = "node=%s received_at=%s finished_comp_at=%s\n"%(
        os.getpid(), start_time, end_time)
    return report

def factorial_(n):
    acc = 1
    for i in range(1,n+1):
        acc *= i
    return acc

@wallaroo.decoder(header_length=4, length_fmt=">I")
def decoder(_any):
    return 1

@wallaroo.encoder
def encoder(report):
    return report
