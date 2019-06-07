import logging
import time


# This first import is required for integration harness and wallaroo lib
# imports to work (it does path mungling to ensure they're available)
import conformance

# Test specific imports
from conformance.applications import WindowDetector
from conformance.completes_when import data_in_sink_contains


# input
out_of_order_ts = [{'ts': 1000000000, 'key': 'key', 'value': 2},
                   {'ts': 1001000000, 'key': 'key', 'value': 3},
                   {'ts': 1002000000, 'key': 'key', 'value': 4},
                   {'ts':         50, 'key': 'key', 'value': 1},
                   {'ts': 1003000000, 'key': 'key', 'value': 5}]

# Expectations
out_of_order_ts_drop = [2, 3, 4, 5]
out_of_order_ts_firepermessage = [1, 2, 3, 4, 5]


def test_drop_policy():
    conf = {'window-late-data-policy': 'drop'}

    # boiler plate test execution entry point
    with WindowDetector(config=conf) as test:
        # Send some data, use block=False to background senders
        # call returns sender instanceA
        test.send(out_of_order_ts)

        # Specify end condition (as function over sink)
        test.completes_when(data_in_sink_contains(out_of_order_ts_drop),
            timeout=30)

        # Test validation logic
        output = test.collect()
        assert(out_of_order_ts_drop == output), (
            "Expected {} but received {}"
            .format(out_of_order_ts_drop, output))


def test_firepermessage_policy():
    conf = {'window-late-data-policy': 'fire-per-message'}

    # boiler plate test execution entry point
    with WindowDetector(config=conf) as test:
        test.send(out_of_order_ts)

        # Specify end condition (as function over sink)
        test.completes_when(
            data_in_sink_contains(out_of_order_ts_firepermessage),
            timeout=30)

        # Test validation logic
        output = test.collect()
        assert(out_of_order_ts_firepermessage == output), (
            "Expected {} but received {}"
            .format(out_of_order_ts_firepermessage, output))
