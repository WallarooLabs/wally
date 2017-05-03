# Wallaroo in Comparison

## Wallaroo and Apache Storm comparison

### Stateful Objects

One of the most important and useful features of Wallaroo is it's stateful data objects.  Any application that requires accuracy would make ample use of them.  When comparing how you would implement recoverable stateful objects in Apache Storm, you get a real sense of Wallaroo's power.

Wallaroo | Apache Storm
---------| -----
 | 
**Stateful Objects** |
* Set configuration "exactly-once=TRUE" | * Make sure message acking is turned on
* Use Wallaroo libraries to create stateful object | * Turn on storm at-least-once messaging
* Store calculations in object | * Setup 3rd party technology for saving state (memcached)
| * Integrate Storm bolt that you want to be stateful with 3rd party technology 
| * Write logic to ensure that transactions are idempotent on message replay
 | 
**State Managemen** |
* State management and recovery is handled for you. | * Design own state management and idempotence or leverage Storm's state management
| * Tune and configure Redis or other key/value store for storing state
| * Design a deduplication strategy
| * Test and verify that out of process interaction with KV store used for storing state works under all failure conditions.
 | 
**Performance** |
* Provides at the framework level | * Attempt to compensate for latency introduced by going out of process to store state. 
* awesome combination of throughput and latency | * Extensive optimization to get control of garbage created. Tune JVM garbage collector. 
* Has built in tail latency friendly garbage collection | 



