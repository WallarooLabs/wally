
# The DOS Service

* [1. About the name](#1_about_the_name)
* [2. Background information](#2_background_information)
* [3. The resiliency demo](#3_the_resiliency_demo)
* [4. Next Steps](#4_next_steps)

## 1. About the name

The "DOS" originally stood for "dumb object service".  It still haven't been renamed, to my chagrin.  The "D" could be changed to mean "distributed".  That would be a technically correct description.

## 2. Background information

I'd written a blog article for Wallaroo Labs in late 2018 that describes the rationale & basic operation of the DOS service.  See [The Treacherous Tangle of Redundant Data: Resilience for Wallaroo](https://blog.wallaroolabs.com/2018/11/the-treacherous-tangle-of-redundant-data-resilience-for-wallaroo/)

## 3. The resiliency demo

This section discussed README and scripts found in the [$WALLAROO_TOP/demos/resilience-demo](https://github.com/WallarooLabs/wallaroo/tree/master/demos/resilience-demo) directory.  That directory contains cut-and-paste'able steps & scripts for demonstrating the DOS service's role in making Wallaroo cluster resilient to machine failure.

We don't actually kill machines.  But we do simulate their failure by:

* Killing the Wallaroo process on a VM `src`, which simulates the failure of the entire `src` VM.
* Copy `src`'s replica data files from a DOS server to a new VM, `dst`.
* Restart the failed Wallaroo worker on the `dst` VM.
* Continue processing stream data, hooray.

## 4. Next Steps

There are a couple of steps that I know are missing from a production-ready Wallaroo system: IP address management, and adding to the checkpoint protocol a synchronous ack of journaled I/O.

#### IP address management

Wallaroo has a very static model of each Wallaroo worker and the IP address & TCP port numbers that each worker uses.  In the case of failing an entire host, it's usually true that the IP address of that host also fails.  If Wallaroo's worker <-> IP address model remains static, then a failed IP address will block the restart of the worker.

Some data center environments can provide an IP address that can move from one host to another.  In such environments, Wallaroo can work without change, assuming that there's enough support for moving IP addresses from failed hosts to new hosts.

1. A Wallaroo cluster is set up and running, including host `A` with IP address `addressA` and a Wallaroo worker process `workerA`.
2. When host `A` crashes, naturally `workerA` is also crashed.
3. The DC detects that `A` has crashed.
    * All of the "The DC" steps might be performed by a human, or by software, it doesn't matter.
4. The DC moves the `addressA` IP address from host `A` to some other host `B`, which is up and running.
5. The DC copies the most-up-to-date replicas of a DOS server's files from the DOS server to the appropriate place on host `B` and runs the `dump-journal.py` process.
6. Worker `workerA` is restarted on host `B`.

That scheme works well, if `addressA` can be moved to a new host.  If `addressA` cannot be moved to a new host, then we have a bit more work to do.

After step #5 above, we can use a kludge technique to compensate for the fact that we're about to start `workerA` on a machine/VM/host/container that doesn't have `addressA` available.  The kludge is demonstrated in the [KLUDGE-TCP-FILES.sh demo script](https://github.com/WallarooLabs/wallaroo/blob/master/demos/resilience-demo/KLUDGE-TCP-FILES.sh), which overwrites the `.tcp-control` and `.tcp-data` data files that provide IP address information to Wallaroo when Wallaroo restarts.

Wallaroo should be able to manage IP address change automatically.  However, doing so creates a tight coupling between Wallaroo and the environment that it's deployed in.  Is the cluster managed by humans in an old-school data center?  Is the cluster managed by Kubernetes?  Or Mesos?  Or by some other H/A software framework?

#### Sync I/O feedback from the DOS client -> checkpoint protocol

Wallaroo's checkpoint protocol makes an assumption that the file I/O that is performed by the protocol is synchronous.  However, the implementation of the DOS client and Wallaroo's use of the DOS client(s)(*footnote*) is asynchronous.  There is no feedback from the DOS client to tell the checkpoint protocol that the remote DOS server has fsync'ed all of the worker's checkpoint data.

Let's illustrate the problem with a failure scenario:

1. A 2-worker Wallaroo cluster is up & running.  Each worker is mirroring its local file I/O to a DOS server.
2. All checkpoints up through checkpoint 42 have been successful and have been written to disk, both locally and on the DOS server.
3. Checkpoint 43 starts.
4. Worker A writes to its local files, sends the local file ops to the DOS server, and completes the checkpoint.
5. Worker B writes to its local files, sends the local file ops to the DOS server, and completes the checkpoint.
6. Wallaroo's checkpoint protocol considers checkpoint 43 to be complete and successful.
7. Worker B's machine crashes.
8. Unfortunately, there was a network problem during step #5 that interfered with the timely sending of worker B's checkpoint data to the DOS server.
9. Using the host replacement procedure described above, worker B is started on a new machine, using the file replica data from the DOS server.
10. We know that B's data at the DOS server is incomplete, unfortunately.
11. When worker B is restarted, and Wallaroo triggers a global rollback, Wallaroo encounters a problem: the state for checkpoint 43 is available at worker A but unavailable at worker B.

If the completion of the checkpoint protocol can wait until each worker has confirmed that its checkpoint data has been received by the remote DOS server and (ideally) `fsync(2)`'ed, then this problem disappears.  Technically speaking, if we assume that only a Wallaroo worker or a DOS server can fail but not both simultaneously, then the `fsync(2)` is not critical.  However, each Wallaroo worker must still wait for a confirmation from the DOS server that all of the checkpoint data has been received.


(*footnote*) Wallaroo can use multiple DOS servers for greater redundancy of locally-written data.