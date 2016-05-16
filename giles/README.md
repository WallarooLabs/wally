# Giles

A tester, you might even say "watcher" for Buffy.

## Relationship to Buffy

Giles acts as an external tester for Buffy. It sends data into Buffy and then
gets data back out. Once it receives data, it can run a number of tests to
verify that the data wasn't corrupted in transit. The goal is to act as an
outside observer and verify that Buffy is operating correctly.

## The components

Giles is split into two binaries: one for sending data, one for receiving data.

## Working with Buffy

```
+----------------+    +----------------------------+    +----------------+
|                |    |           Buffy            |    |                |
|  Giles sender  |    |                            |    | Giles receiver |
|                |----+>                          -+--->|                |
|                |    |                            |    |                |
+----------------+    +----------------------------+    +----------------+
```

In a simple locally running topology like the one we have above
and assuming that our Buffy source is listening on port 8081 locally
and that its Sink will send data to port 8082, then you would
start Giles as follows:

```
./giles/receiver -b 127.0.0.1:8082
./giles/sender -b 127.0.0.1:8081 -m 100
```

The receiver should be started before the sender otherwise data will be lost. By
the same token, the sender should be shut down before the receiver to prevent
data loss. Once you start running the sender, it will immediately start
sending data.

The Giles sender will shutdown once it has finished sending the number of
messages requested. While running the sender and receiver both log the their
data to `sent.txt` and `received.txt` respectively. The sender will shutdown
when it is finished sending data. To shutdown the receiver, send a TERM signal
to the process. 

Re: logged of output to files, neither Giles process calls `flush` until exiting
so its possible that what you see in the log is out of date as all contents
might not have been flushed yet.

Currently the Giles sender sends messages in one of two way:

- With no other commandline options given, it will send string
  representations of integers, starting with `1` and increasing by `1`
  with each new message. For example, `./giles/sender -b 127.0.0.1:8081
  -m 100` will send messages containing string representations of the
  numbers `1` through `100`.
- With a file name given as the last argument it will send each line
  of the given file as a message. For example, `./giles/sender
  -b 127.0.0.1:8081 -m 100 -f war-and-peace.txt` will send messages containing
  each of the first 100 lines of the file `war-and-peace.txt`.

## Working with Dagon

If you are coordinating Giles with Dagon, then Dagon will handle passing the
correct command line arguments. See Dagon README for instructions.

