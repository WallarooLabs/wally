# CI Log Analyzer - Wallaroo Dogfood Application

This application implements the CI error log streaming analysis dogfood application requested in [#1812](https://github.com/WallarooLabs/wally/issues/1812).

## Overview

Continuous Integration pipelines generate streams of test execution outputs. This Wallaroo application instruments CI log events as a stateful stream to compute:
- **Error Rate by File**: Dynamically computes failure frequency per test/source file.
- **Recurring Failure Detection**: Detects and alerts on persistent/flaky failures (3+ consecutive test failures).
- **High Failure Rate Alerts**: Notifies downstream systems when failure rate spikes above threshold (>25%).

## Pipeline Topology

```
[CI Log Source] (GenSource / TCP Log Stream)
        │
        ▼
   [key_by(file_path)]
        │
        ▼
[track_and_analyze_file_errors] (Stateful: FileErrorStats)
        │
        ▼
   [encode_ci_alert] (JSON Sink)
```

## Input Configuration

The application uses an internal generator source (`CILogGenerator`), which synthesizes streaming CI test execution logs across multiple source files and tests. Because input is generated automatically by Wallaroo upon initialization, no external TCP `--in` input address parameter is required.

## Running the Application

### Running with Machida (Python 2.7 / 3)

Start Machida (or `machida3` for Python 3):

```bash
machida --application-module ci_log_analyzer \
  --out 127.0.0.1:5555 \
  --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 \
  --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1 --ponynoblock
```

### Running the Validation Tests

To run the unit test validation directly:

```bash
python3 _validate.py --unit-tests-only
```
