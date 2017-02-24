# Testing Behaviour with Metrics

## Description

Metrics is an external service that the application periodically sends data to. To reduce congestion and load, aggregation and buffering is done by the application. When the metrics destination becomes unavailable, the application is expected to shed the metrics load until the metrics destination becomes available again.

## Testing Reconnecting to a Metrics Destination

### Steps:

1. sink: `nc -l 127.0.0.1 5555`
1. metrics: `nc -l 127.0.0.1 5001`
1. app: `./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -m 127.0.0.1:5001`
1. sender: `sender -b 127.0.0.1:7000 -s 1 -i 1_000_000_000 -y -g 12 -w -u -m 100`
1. terminate metrics with `Ctrl-C`
1. restart metrics

### Expectation:

1. Application starts successfully.
1. Once metrics is terminated, application begins reports the change and begins shedding load
1. Once metrics is restarted, application reconnects to it, reports the change, and resumes sending metrics data

### Observed:

1. Application starts successfully
1. Once metrics is terminated, application does not report the change. There's no easy way to tell if it's shedding load other than adding some Debug statements in the metrics code currently, since we're not running a high load test that would cause noticable memory bloat.
1. Once metrics is restarted, application does not reconnect, does not report change (because that never happens), and does not resume sending metrics data.


## Testing Starting with an Offline Metrics Destination

### Steps:

1. sink: `nc -l 127.0.0.1 5555`
1. app: `./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -m 127.0.0.1:5001`
1. sender: `sender -b 127.0.0.1:7000 -s 1 -i 1_000_000_000 -y -g 12 -w -u -m 100`
1. Wait a while for some metrics to be sent (10-20 seconds?)
1. start metrics: `nc -l 127.0.0.1 5001`

### Expectation:

1. Application starts successfully
1. Application reports metrics is not available and sheds metrics load
1. Metrics becomes online
1. Application connects to metrics, report status change, and starts collecting/sending metrics

### Observed:

1. Application starts successfully
1. Application initially sheds metrics load, but does not report metrics is unavailable
1. Metrics becomes online
1. Application does not connect to metrics, does not report change, and does not begin collecting/sending metrics

## Testing Starting Without a Metrics Destination

### Steps:
1. sink: `nc -l 127.0.0.1 5555`
1. app: `./sequence-window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -c 127.0.0.1:12500 -d 127.0.0.1:12501`

### Expectation:
1.Application starts successfully
1.Application reports no metrics destination is provided and metrics load will be shed

### Observed:
1. Application fails to start since --metrics/-m is a required parameter
