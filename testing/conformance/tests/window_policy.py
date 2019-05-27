import json
import logging
import time


# This first import is required for integration harness and wallaroo lib
# imports to work (it does path mungling to ensure they're available)
import conformance

# Test specific imports
from conformance.applications import WindowDetector
from conformance.configurations import base_window_policy
from conformance.inputs import out_of_order_ts
from conformance.expectations import (out_of_order_ts_drop,
                                      out_of_order_ts_firepermessage)

# Get a data generator
from integration.end_points import iter_generator


# Provide a function for iter_generator to use to serialise each item
def serialise_input(v):
    return json.dumps(v).encode()


# A function for converting byte output from sink to match expectation values
def parse_output(bs):
    logging.debug('parse_output: {}'.format(repr(bs)))
    return json.loads(bs[4:])['value']


def test_drop_policy():
    # Test specific configration
    policy = base_window_policy.copy()
    policy['window-policy'] = 'drop'

    # boiler plate test execution entry point
    with WindowDetector(config=policy) as test:
        # Create a data generator
        gen = iter_generator(items=out_of_order_ts, to_bytes = serialise_input)

        # Send some data, use block=False to background senders
        # call returns sender instance
        test.send_tcp(gen)

        # Specify end condition (as function over sink)
        test.sink_await(out_of_order_ts_drop, timeout=30, func=parse_output)

        # Test validation logic
        output = []
        for fd, stream in test.collect().items():
            # merge streams
            for message in stream:
                output.append(parse_output(message))
        assert(out_of_order_ts_drop == output), (
            "Expected {} but received {}"
            .format(out_of_order_ts_drop, output))


def test_firepermessage_policy():
    # Test specific configration
    policy = base_window_policy.copy()
    policy['window-policy'] = 'fire-per-message'

    # boiler plate test execution entry point
    with WindowDetector(config=policy) as test:
        # Create a data generator
        gen = iter_generator(items=out_of_order_ts, to_bytes = serialise_input)

        # Send some data, use block=False to background senders
        # call returns sender instance
        test.send_tcp(gen)

        # Specify end condition (as function over sink)
        test.sink_await(out_of_order_ts_drop, timeout=30, func=parse_output)

        # Test validation logic
        output = []
        for fd, stream in test.collect().items():
            # merge streams
            for message in stream:
                output.append(parse_output(message))
        assert(out_of_order_ts_firepermessage == output), (
            "Expected {} but received {}"
            .format(out_of_order_ts_firepermessage, output))
