#!/usr/bin/env python3

"""Metrics listens on a specified address and parses metrics messages
and pretty prints them to console
"""


import click
import datetime
import json
import socket


def parse_metrics(buf):
    data = json.loads(buf.decode())
    if data['throughput_in']:
        throughputs = "\n".join([
            "        {timestamp: <15s}{t_in: <10d}{t_out: <10d}".format(
                timestamp=str(datetime.datetime.fromtimestamp(k).time()),
                t_in=t_in,
                t_out=t_out)
            for k, t_in, t_out in [(float(k),
                                   data['throughput_in'][k],
                                   data['throughput_out'][k])
                                   for k in sorted(data['throughput_in']
                                                   .keys())]])
    else:
        throughputs = ""

    if data['latency_time']:
        latencies = "\n".join([
            "        {bin: <15s}{mean: <15.9f}{pct:>5.2f}  {count: <9d}{sum: <15.9f}"
                     .format(
                bin=k,
                mean=data['latency_time'][k]/data['latency_count'][k],
                pct=100*data['latency_count'][k]/sum(data['latency_count'].values()),
                count=data['latency_count'][k],
                sum=data['latency_time'][k])
            for k in sorted(data['latency_time'].keys())])
    else:
        latencies = ""

    text = """
    Vertex: {VUID}
    Function: {func}
    Measurement Period: ({d0}, {d1}]
    Throughput:
        TIME           IN        OUT
{throughputs}
    Latency:
        BIN (max)      MEAN           PCT    COUNT    SUM
{latencies}

    """.format(VUID=data['VUID'],
               func=data['func'],
               d0=datetime.datetime.fromtimestamp(data['t0']),
               d1=datetime.datetime.fromtimestamp(data['t1']),
               throughputs=throughputs,
               latencies=latencies)

    return text


@click.command()
@click.option('--address', default='127.0.0.1:10000',
              help='Address to listen on')
def listen(address):
    host, port = [f(x) for f, x in
                  zip((str, int), address.split(':'))]
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((host, port))

    while True:
        buf = sock.recv(65507)
        if buf:
            try:
                print(parse_metrics(buf))
            except:
                print(buf)
                raise


def test_parse():
    buf = b'{"t1": 1458195070.3131151, "VUID": "NTg2ODIx", "latency_time": {"0.000100000 s": 0.13107776641845703, "0.001000000 s": 0.033399105072021484}, "latency_count": {"0.000100000 s": 2449, "0.001000000 s": 227}, "throughput_out": {"1458195069": 1507, "1458195070": 1169}, "func": "Marketspread", "throughput_in": {"1458195069": 1507, "1458195070": 1169}, "t0": 1458195068.309974}'
    print(parse_metrics(buf))
    assert(0)


if __name__ == '__main__':
    listen()
