# Giles

A tester, you might even say "watcher" for Buffy.

## Relationship to Buffy

Giles acts as an external tester for Buffy. It sends data into
Buffy and then gets data back out. Once it receives data, it can
run a number of tests to verify that the data wasn't corrupted
in transit.

As Giles grows, it will run a variety of validations on the data
as well as capture key metrics. The goal is to act as an outside
observer and verify that Buffy is operating correctly. 

## Setting up with the Buffy prototype

           +----------------------------------------------+
           |                                              |
           v               +----------------------------+ |
  +----------------+       |                            | |
  |                |       |                            | |
  |     Giles      |       |           Buffy            | |
  |                |-----+ |   +------+         +------+| |
  |                |     +-+-->|Queue |-------->|Worker|+-+
  +----------------+       |   +------+         +------+|
                           +----------------------------+
                           
In a simple locally running topology like the one we have above
and assuming that Buffy's Queue is listening on port 8081 locally
and that the worker is listening on port 8082, then you would start 
Giles as follows:

`./giles 127.0.0.1 QUEUE_INCOMING_PORT 127.0.0.1 WORKER_OUTGOING_PORT`

Once you start running Giles running, it will immediately start sending
data on its outgoing port (to the queue's incoming port). At the moment,
that data is a monotonically increasing U64.
