# Merrick

A process that writes incoming TCP messages to file, created specifically for the use of writing outgoing Wallaroo metrics to file.

## Working with Wallaroo

### Without Metrics Forwarding

Assuming that our Wallaroo app is writing metrics to port 5001 locally, you would start the Metrics Receiver as follows:

```
./merrick -l 127.0.0.1:5001 -o metrics-received.txt
```

### With Metrics Forwarding

Assuming that our Wallaroo app is writing metrics to port 5005 locally and the UI is running on port 5001, you would start the Metrics Receiver as follows:

```
./merrick -l 127.0.0.1:5001 -o metrics-received.txt -f -m 127.0.0.1:5001
```

Merrick should be started before the Wallaroo application, otherwise there is a chance data will be lost.

While running Merrick it will log it's data to `metrics-received.txt`. To shutdown Merrick, send a TERM signal to the process.

Re: log of output to files, Merrick doesn't call `flush` until exiting
so its possible that what you see in the log is out of date as all contents
might not have been flushed yet.

