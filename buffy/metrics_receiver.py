#!/usr/bin/env python3

"""Metrics listens on a specified address and parses metrics messages
and pretty prints them to console
"""


import asyncio
import click
import datetime
import json
import requests


def parse_metrics(buf):
    data = json.loads(buf.decode())
    t_len = max((len(data['throughput_in'] or []),
                 len(data['throughput_out'] or [])))
    if t_len > 0:
        keys, throughput_in, throughput_out = [], [] , []
        for k in sorted(set((data['throughput_in'] or {}).keys())
                        .union((data['throughput_out'] or {}).keys())):
            keys.append(k)
            throughput_in.append((data['throughput_in'] or {}).get(k, 0))
            throughput_out.append((data['throughput_out'] or {}).get(k, 0))

        throughputs = "\n".join([
            "        {timestamp: <15s}{t_in: <10d}{t_out: <10d}".format(
                timestamp=str(datetime.datetime.fromtimestamp(float(k))
                              .time()),
                t_in=t_in,
                t_out=t_out)
            for k, t_in, t_out in zip(keys, throughput_in, throughput_out)])
    else:
        throughputs = ""

    if data['latency_time']:
        latencies = "\n".join([
            "        {bin: <20s}{mean: <15.9f}{pct:>6.2f}  {count: <9d}{sum: <15.9f}"
                     .format(
                bin=k,
                mean=data['latency_time'][k]/data['latency_count'][k],
                pct=100*data['latency_count'][k]/sum(data['latency_count'].values()),
                count=data['latency_count'][k],
                sum=data['latency_time'][k])
            for k in sorted(data['latency_time'].keys())])
        latencies_header = ("        {bin: <20s}{mean: <15s}{pct:^6s}  "
                            "{count: <9s}{sum: <15s}\n").format(
                                bin='BIN (max)',
                                mean='MEAN',
                                pct='PCT',
                                count='COUNT',
                                sum='SUM')

    else:
        latencies = ""
        latencies_header = ""

    text = """
    Vertex: {VUID}
    Function: {func}
    Measurement Period: ({d0}, {d1}]
    Throughput:
        TIME           IN        OUT
{throughputs}
    Latency:
{latencies_header}{latencies}

    """.format(VUID=data['VUID'],
               func=data['func'],
               d0=datetime.datetime.fromtimestamp(data['t0']),
               d1=datetime.datetime.fromtimestamp(data['t1']),
               throughputs=throughputs,
               latencies_header=latencies_header,
               latencies=latencies)

    return text


def post(uri, data=None, json=None):
    response = requests.post(uri, data=data, json=json)


class UDPMessageQueue(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        try:
            print(parse_metrics(data))
            post(URI, None, json.loads(data.decode()))
        except:
            print(data)

    def connection_lost(self, exc):
        self.transport = None


@click.command()
@click.option('--address', default='127.0.0.1:10000',
              help='Address to listen on')
@click.option('--uri', default='http://127.0.0.1:5000/',
              help='URI for the Monitoring Hub')
def listen(address, uri):
    host, port = [f(x) for f, x in
                  zip((str, int), address.split(':'))]

    global URI
    URI = uri
    # Create the main event loop object
    loop = asyncio.get_event_loop()
    # One protocol instance will be created to serve all client requests
    listen = loop.create_datagram_endpoint(
        UDPMessageQueue, local_addr=(host, port))
    transport, protocol = loop.run_until_complete(listen)

    # Start the listener event loop and run until SIGINT
    try:
        loop.run_forever()
    except KeyboardInterrupt:
        pass

    transport.close()
    loop.close()


def test_parse():
    buf = b'{"t1": 1458195070.3131151, "VUID": "NTg2ODIx", "latency_time": {"0.000100000 s": 0.13107776641845703, "0.001000000 s": 0.033399105072021484}, "latency_count": {"0.000100000 s": 2449, "0.001000000 s": 227}, "throughput_out": {"1458195069": 1507, "1458195070": 1169}, "func": "Marketspread", "throughput_in": {"1458195069": 1507, "1458195070": 1169}, "t0": 1458195068.309974}'
    assert(parse_metrics(buf))


if __name__ == '__main__':
    listen()
