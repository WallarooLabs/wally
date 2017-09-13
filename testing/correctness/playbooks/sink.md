# Testing Sink in Wallaroo

## Description
Sink is the final destination of the application data. The ultimate step of the application sends output to the sink.
The purpose of these tests is to validate that the behaviour of the application is consistent as a sink becomes unavailable during its lifetime.

## Testing Reconnecting to a Sink

### Steps:

1. sink: `nc -l 127.0.0.1 5555`
1. app: `./sequence_window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -m 127.0.0.1:5001 -t`
1. sender: `sender -h 127.0.0.1:7000 -s 1 -i 1_000_000_000 -y -g 12 -w -u -m 100`
1. terminate sink with `Ctrl-C`
1. restart sink

### Expectation:
1. Application starts successfully.
1. Once sink is terminated, application MUTEs, and reports this status change
1. Once sink is restarted, application reconnects to it and UNMUTEs, and reports the status change

### Observed:
1. Application starts successfully
1. Once sink is terminated, application MUTEs, but does not report status change
1. Once sink is restarted, application does not reconnect and never UNMUTEs, no status change reported


## Testing Starting with an Offline Sink

### Steps:

1. app: `./sequence_window -i 127.0.0.1:7000 -o 127.0.0.1:5555 -c 127.0.0.1:12500 -d 127.0.0.1:12501 -m 127.0.0.1:5001 -t`
1. sender: `sender -h 127.0.0.1:7000 -s 1 -i 1_000_000_000 -y -g 12 -w -u -m 100`
1. wait a few seconds
1. sink: `nc -l 127.0.0.1 5555`

### Expectation:

1. Application starts and immediately MUTES
1. sender does not send data after the first batch, since the application is MUTED
1. Once sink comes online, application connects to it, UNMUTEs, reports this
1. sender sends more batches

### Observation:

1. Application exits immediately with error This should never happen: `failure in /home/nisan/proj/wallaroolabs/wallaroo/lib/wallaroo/tcp_sink/tcp_sink.pony at line 745`
