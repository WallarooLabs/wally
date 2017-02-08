# Merrick

A process that writes incoming TCP messages to file, created specifically for the use of writing outgoing Wallaroo metrics to file.

## Working with Wallaroo

Assuming that our Wallaroo app is writing metrics to port 5001 locally, you would start the Metrics Receiver as follows:

```
./merrick -l 127.0.0.1:5001 -o metrics-received.txt
```

Merrick should be started before the Wallaroo application, otherwise there is a chance data will be lost.

While running Merrick it will log it's data to `metrics-received.txt`. To shutdown Merrick, send a TERM signal to the process. 

Re: log of output to files, Merrick doesn't call `flush` until exiting
so its possible that what you see in the log is out of date as all contents
might not have been flushed yet.


## Working with Dagon

If you are coordinating Merrick with Dagon, then Dagon will handle passing the
correct command line arguments. See Dagon README for instructions.

