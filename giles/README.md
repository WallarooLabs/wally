# Giles

A tester, you might even say "watcher" for Buffy.

Ver 0.1.1-sendence

## Relationship to Buffy

Giles acts as an external tester for Buffy. It sends data into Buffy and then
gets data back out. Once it receives data, it can run a number of tests to
verify that the data wasn't corrupted in transit. The goal is to act as an
outside observer and verify that Buffy is operating correctly.

## The components

Giles is split into two binaries: one for sending data, one for receiving data.

## Setting up with the Buffy prototype

```
+----------------+    +----------------------------+    +----------------+
|                |    |           Buffy            |    |                |
|  Giles sender  |    | +------+          +------+ |    | Giles receiver |
|                |----+>|Queue |--------->|Worker|-+--->|                |
|                |    | +------+          +------+ |    |                |
+----------------+    +----------------------------+    +----------------+
```                           
In a simple locally running topology like the one we have above
and assuming that Buffy's Queue is listening on port 8081 locally
and that the worker is listening on port 8082, then you would start 
Giles as follows:

```
./giles/receiver 127.0.0.1:8082
./giles/sender 127.0.0.1:8081
```

The receiver should be started before the sender otherwise data will be lost. By
the same token, the sender should be shut down before the receiver to prevent
data loss. Once you start running the sender, it will immediately start
sending data.

To shutdown a Giles process, be it sender or receiver, send a TERM signal to the
process. This will cause it to write out its data and shutdown.
