from resilience import (Crash,
                        Grow,
                        Recover,
                        Shrink,
                        Wait,
                        _test_resilience)


# TODO:
# - [x] Figure out issue with sender unable to connect
# - [ ] Add test code generator
# - [ ] add: AddSource operation (and logic to validate)
# - [x] background crash detector with notifier-short-circuit capability
#       to eliminate timeout periods when a test fails due to crashed workers
# - [x] Clean out dev debug logs

#############
# Test spec(s)
#############

# some fixed tests:
def test_grow1_shrink1_crash2_wait1_recover2():
    command = 'multi_partition_detector --depth 1'
    ops = [Grow(1), Shrink(1), Crash(2), Wait(1), Recover(2)]
    _test_resilience(command, ops, validate_output=True)


def test_crash1_recover1():
    command = 'multi_partition_detector --depth 1'
    ops = [Crash(1), Recover(1)]
    _test_resilience(command, ops, validate_output=True)


def test_crash2_wait2_recover2():
    command = 'multi_partition_detector --depth 1'
    ops = [Crash(2), Wait(2), Recover(2)]
    _test_resilience(command, ops, validate_output=True)


def test_grow1_wait2_shrink1_wait_2_times_ten():
    command = 'multi_partition_detector --depth 1'
    ops = [Grow(1), Wait(2), Shrink(1), Wait(2)]
    _test_resilience(command, ops, validate_output=True, cycles=10)


# The following tests only works if multi_partition_detector is compiled
# with -D allow-invalid-state
#def test_continuous_sending_crash2_wait2_recover2():
#    command = 'multi_partition_detector --depth 1'
#    ops = [Crash(2, pause=False), Wait(2), Recover(2, resume=False)]
#    _test_resilience(command, ops, validate_output=False)
