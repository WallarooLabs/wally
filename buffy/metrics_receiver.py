#!/usr/bin/env python3

"""Metrics listens on a specified address and parses metrics messages,
pretty prints them to console, and sends out a metrics data set
to the monitoring hub
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


def process_for_dashboard(buf):
    """Process incoming metrics data into the format expected by the
    Monitoring Hub."""
    data = json.loads(buf.decode())
    if not data['latency_count']:
        return
    output = {}
    output['pipeline_key'] = data['VUID']
    output['t1'] = data['t1']
    output['t0'] = data['t0']
    output['topics'] = {}

    # latency bins
    output['topics']['latency_bins'] = {float(key.split()[0]): val
                                        for key, val in
                                        data['latency_count'].items()}

    # throughput out
    output['topics']['throughput_out'] = {int(key.split()[0]): val
                                          for key, val in
                                          data['throughput_out'].items()}
    # Post the output as an application/json content-type
    post(uri=URI, data=None, json=output)


def post(uri, data=None, json=None):
    requests.post(uri, data=data, json=json)


class UDPMessageQueue(asyncio.DatagramProtocol):
    def connection_made(self, transport):
        self.transport = transport

    def datagram_received(self, data, addr):
        try:
            print(parse_metrics(data))
            process_for_dashboard(data)
        except:
            print(data)
            raise

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
    if uri:
        URI = uri
    else:
        URI = None
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
