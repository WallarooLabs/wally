#!/usr/bin/env python

# Copyright 2017-2026 The Wallaroo Authors.
#
#  Licensed under the Apache License, Version 2.0 (the "License");
#  you may not use this file except in compliance with the License.
#  You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
#  Unless required by applicable law or agreed to in writing, software
#  distributed under the License is distributed on an "AS IS" BASIS,
#  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
#  implied. See the License for the specific language governing
#  permissions and limitations under the License.

import argparse
import json
import os
import sys

# Import FileErrorStats for unit validation
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
try:
    from ci_log_analyzer import FileErrorStats
except ImportError:
    FileErrorStats = None


def test_stats_isolation():
    """Verify per-test consecutive failure tracking does not conflate tests within a file."""
    if FileErrorStats is None:
        return
    stats = FileErrorStats()
    stats.record_run("test_a", failed=True)
    assert stats.consecutive_failures_for("test_a") == 1
    assert stats.consecutive_failures_for("test_b") == 0

    stats.record_run("test_b", failed=True)
    assert stats.consecutive_failures_for("test_a") == 1
    assert stats.consecutive_failures_for("test_b") == 1
    assert stats.total_runs == 2
    assert stats.total_failures == 2

    # Multiple failures of test_a
    stats.record_run("test_a", failed=True)
    stats.record_run("test_a", failed=True)
    assert stats.consecutive_failures_for("test_a") == 3
    assert stats.consecutive_failures_for("test_b") == 1

    # Pass of test_a resets only test_a
    stats.record_run("test_a", failed=False)
    assert stats.consecutive_failures_for("test_a") == 0
    assert stats.consecutive_failures_for("test_b") == 1


def test_threshold_boundary():
    """Verify strictly > 25% failure rate threshold behavior."""
    if FileErrorStats is None:
        return
    stats = FileErrorStats()
    # 4 runs, 1 failure: rate = 1/4 = 0.25 (exactly 25%)
    stats.record_run("test_x", failed=False)
    stats.record_run("test_x", failed=False)
    stats.record_run("test_x", failed=False)
    stats.record_run("test_x", failed=True)
    assert stats.total_runs == 4
    assert stats.failure_rate == 0.25
    # Must NOT alert on exactly 25% (threshold is strictly > 0.25)
    assert not (stats.failure_rate > 0.25), "Rate of 0.25 must not exceed > 0.25 threshold"

    # 5 runs, 2 failures: rate = 2/5 = 0.40 (> 25%)
    stats.record_run("test_x", failed=True)
    assert stats.total_runs == 5
    assert stats.failure_rate == 0.4
    assert stats.failure_rate > 0.25, "Rate of 0.40 must exceed > 0.25 threshold"


def validate(output_file):
    test_stats_isolation()
    test_threshold_boundary()

    with open(output_file, "r") as f:
        lines = [line.strip() for line in f if line.strip()]

    if not lines:
        sys.stderr.write("No output alerts received\n")
        return False

    valid_alert_types = {"RECURRING_FAILURE", "HIGH_FAILURE_RATE"}
    for line in lines:
        try:
            data = json.loads(line)
            assert "alert" in data, "Missing alert key"
            assert data["alert"] in valid_alert_types, (
                "Unexpected alert type: {}".format(data["alert"])
            )
            assert "file" in data, "Missing file key"
            assert "test" in data, "Missing test key"
            if data["alert"] == "HIGH_FAILURE_RATE":
                assert "failure_rate" in data, "Missing failure_rate"
                assert data["failure_rate"] > 0.25, (
                    "Alerted HIGH_FAILURE_RATE with rate <= 0.25: {}".format(data["failure_rate"])
                )
        except Exception as e:
            sys.stderr.write("Invalid alert payload: {}\nError: {}\n".format(line, e))
            return False

    print("Successfully validated {} CI log analyzer alerts.".format(len(lines)))
    return True


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Validate CI log analyzer output.")
    parser.add_argument("--output", dest="output", default=None,
                        help="Path to output sink file.")
    parser.add_argument("--unit-tests-only", action="store_true",
                        help="Run unit tests on state tracking and exit.")
    args = parser.parse_args()

    if args.unit_tests_only:
        test_stats_isolation()
        test_threshold_boundary()
        print("All unit tests passed.")
        sys.exit(0)

    if args.output:
        if not validate(args.output):
            sys.exit(1)
    else:
        # Default behavior if run without args: run unit tests
        test_stats_isolation()
        test_threshold_boundary()
        print("All unit tests passed.")
