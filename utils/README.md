# General Utilities for working with Buffy outputs


## run_length
Reads a giles sent.txt and received.txt (in readable format) to produce a total run-length

```
Usage: run_length [OPTIONS]

Options:
  -s, --sent TEXT    Path of the giles sent file  [required]
  -r, --recd TEXT    Path of the giles received file in readable format
                     [required]
  -c, --count-lines  Fail if line counts don't match
  --help             Show this message and exit.
```


## verify_report
Verify that the data in a metrics report adds up to congruent aggregate buckets.
This means that the population count of the histogram in a certain time range should match that of the population count in the throughput history for the same time range.

```
Usage: verify_report [OPTIONS]

Options:
  -r, --report TEXT  Path of report file to verify  [required]
  --help             Show this message and exit.
```


## summarize_report
Summarize a report file from the metrics receiver into a into a single aggregate.

```
Usage: summarize_report [OPTIONS]

Options:
  -r, --report TEXT               Path of report file to verify  [required]
  -b, --bin-type [FixedBins|Log10Bins]
  --verify / -V, --no-verify
  --help                          Show this message and exit.
```


## summarize_giles
Summarize a pair of giles sent.txt and received.txt (in readable format) files to produce a source-sink metrics summary which can be compared against the metrics receiver's source-sink summary.

```
Usage: summarize_giles [OPTIONS]

  Summarize a pair of giles sent and received text logs into a source-sink
  metrics summary.

Options:
  -s, --sent TEXT                 Path of the giles sent file  [required]
  -r, --recd TEXT                 Path of the giles received file  [required]
  -b, --bin-type [FixedBins|Log10Bins]
  --help                          Show this message and exit.
```
