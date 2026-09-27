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

"""
CI Log Analyzer - A Wallaroo Dogfood Application (Closes #1812)

Instruments CI error logs as a streaming pipeline to analyze:
1. Error rate by file over streaming test executions
2. Recurring test failure detection
3. Critical test failure alerting
"""

import json
import wallaroo


def application_setup(args):
    out_host, out_port = wallaroo.tcp_parse_output_addrs(args)[0]

    gen_source = wallaroo.GenSourceConfig(
        "CI Log Stream",
        CILogGenerator()
    )

    log_stream = wallaroo.source("CI Log Stream", gen_source)
    pipeline = (log_stream
        .key_by(extract_file_key)
        .to(track_and_analyze_file_errors)
        .to_sink(wallaroo.TCPSinkConfig(out_host, out_port, encode_ci_alert)))

    return wallaroo.build_application("CI Log Analyzer", pipeline)


class CILogEvent(object):
    def __init__(self, file_path, test_name, status, error_message=""):
        self.file_path = file_path
        self.test_name = test_name
        self.status = status  # 'PASS' or 'FAIL'
        self.error_message = error_message


class FileErrorStats(object):
    def __init__(self):
        self.total_runs = 0
        self.total_failures = 0
        self.consecutive_failures = 0

    def record_run(self, failed):
        self.total_runs += 1
        if failed:
            self.total_failures += 1
            self.consecutive_failures += 1
        else:
            self.consecutive_failures = 0

    @property
    def failure_rate(self):
        if self.total_runs == 0:
            return 0.0
        return float(self.total_failures) / float(self.total_runs)


class CIAlert(object):
    def __init__(self, alert_type, file_path, test_name, message, rate=None):
        self.alert_type = alert_type
        self.file_path = file_path
        self.test_name = test_name
        self.message = message
        self.rate = rate

    def to_dict(self):
        payload = {
            "alert": self.alert_type,
            "file": self.file_path,
            "test": self.test_name,
            "message": self.message,
        }
        if self.rate is not None:
            payload["failure_rate"] = round(self.rate, 2)
        return payload

    def __str__(self):
        return json.dumps(self.to_dict())


@wallaroo.key_extractor
def extract_file_key(event):
    return event.file_path


@wallaroo.state_computation(name="analyze file errors", state=FileErrorStats)
def track_and_analyze_file_errors(event, state):
    is_failure = event.status == "FAIL"
    state.record_run(is_failure)

    # 1. Alert on consecutive recurring test failures (flaky / persistent regression)
    if state.consecutive_failures >= 3:
        return CIAlert(
            alert_type="RECURRING_FAILURE",
            file_path=event.file_path,
            test_name=event.test_name,
            message="Test failed 3 or more times consecutively.",
            rate=state.failure_rate,
        )

    # 2. Alert on high failure rate threshold (rate > 25% after at least 4 runs)
    if state.total_runs >= 4 and state.failure_rate >= 0.25 and is_failure:
        return CIAlert(
            alert_type="HIGH_FAILURE_RATE",
            file_path=event.file_path,
            test_name=event.test_name,
            message="Elevated error rate detected for file.",
            rate=state.failure_rate,
        )


@wallaroo.encoder
def encode_ci_alert(alert):
    return (str(alert) + "\n").encode()


##################################################
# GENERATOR FOR DOGFOOD CI LOG TEST STREAM
##################################################
class CILogGenerator(object):
    counter = 0
    test_files = [
        ("lib/wallaroo/tcp_sink.pony", "test_tcp_connection_retry"),
        ("machida/machida.py", "test_stateful_partitioning"),
        ("examples/python/word_count/word_count.py", "test_word_count_pipeline"),
        ("connectors/kafka/source.pony", "test_kafka_offset_commit"),
    ]

    def initial_value(self):
        return CILogEvent("lib/wallaroo/tcp_sink.pony", "test_tcp_connection_retry", "PASS")

    def apply(self, prev):
        self.counter += 1
        file_path, test_name = self.test_files[self.counter % len(self.test_files)]

        # Simulate failures periodically to trigger detection thresholds
        if self.counter % 5 == 0 or (file_path == "machida/machida.py" and self.counter > 6):
            status = "FAIL"
            err = "AssertionError: expected connection state READY"
        else:
            status = "PASS"
            err = ""

        return CILogEvent(file_path, test_name, status, err)
