import argparse

def parse_udp_params(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--udp-host', dest='udp_host', default='127.0.0.1')
    parser.add_argument('--udp-port', type=int, dest='udp_port', default=30000)
    params = parser.parse_known_args(args)[0]
    return params
