import argparse

def parse_kafka_params(args):
    parser = argparse.ArgumentParser()
    parser.add_argument('--bootstrap-broker', dest='bootstrap_broker', default='127.0.0.1:9092')
    parser.add_argument('--topic', dest='topics', action='append')
    parser.add_argument('--consumer-group', dest='consumer_group', default='wallaroo')
    params = parser.parse_known_args(args)[0]
    return params
