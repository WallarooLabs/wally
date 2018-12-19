---
title: "Data Redundancy"
menu:
  docs:
    parent: "operators-manual"
    weight: 30
toc: true
---
## Wallaroo's resilience data directory

As described in the [crash resilience chapter](../resilience-crash/), Wallaroo requires a compile-time flag to enable crash resilience features.  In addition to the `--run-with-resilience` flag, the `--resilience-dir` flag specifies the path to Wallaroo's crash resilience data directory.  The resilience data directory contains worker-specific information for:

* Hostnames/IP addresses and TCP ports for other Wallaroo workers in the cluster

* Source, sink, and pipeline topology information for the cluster's application

* State information for state computations: dynamic keys processed by this worker and user-specified Python/Go/Pony data structures for state computations.

If a Wallaroo worker process crashes and restarts, the files in the resilience data directory provide the necessary information to:

* reconnect to the surviving cluster worker processes,

* participate in the Chandy-Lamport snapshot algorithm's recovery procedure to, which rolls back the global cluster state to a well-defined state, and

* reconfigure local state computation actors to restore the app's user-specified Python/Go/Pony data structures to match the global cluster state snapshot

## Loss of the resilience data directory -> crash recovery is impossible

As outlined in the previous section, the resilience data directory on each Wallaroo worker plays a vital role in the crash recovery process.  Wallaroo can recover from worker crashes as long as the resilience data directory's files are available.

However, not all system failures can leave the resilience data directory's files intact.  Disk drives crash.  Operating system bugs can corrupt the file system.  Entire machines fail, for example, due to a power supply failure.  Virtual machines can be accidentally damaged or destroyed by administrator error.

## Catastrophic failure resilience requires data replication

To protect against catastrophic data loss of the resilience data directory, Wallaroo can replicate the directory's data to remote machines.  If a Wallaroo worker fails catastrophically and loses its local copy of the resilience data directory, the directory can be reconstructed from a remote replica.  The overall outline of events is:

1. A Wallaroo cluster is created and operating normally.  The cluster is configured to replicate its resilience data to a remote server *R*.

2. One of the cluster workers (let's call it *W*) fails catastrophically.  Its resilience data directory is not recoverable.  Let's call the failed physical machine/virtual machine/container *W_f*.

3. A replacement cluster worker must be chosen by a human administrator or external cluster management framework.  Let's call this new machine or container *W_r*.

4. The Wallaroo software is installed on the *W_r* machine.

5. The journal data files belonging to worker *W* are copied from the remote server *R* to the replacement machine *W_r*.

6. Run the journal replay utility to reconstruct *W*'s resilience data directory files.

7. Restart worker *W* on the replacement machine *W_r*, using the same command line arguments as the original *W* worker was run on the original machine *W_f*.

## I/O journals: the foundation for data replication

When Wallaroo is run with the `--resilience-enable-io-journal` flag, then all file-altering I/O to the resilience data directory's files are written to a journal, or write-ahead log.  Wallaroo currently uses two different journal files, based on the type of file I/O generated internally by Wallaroo.  The two journal files can be replicated to a remote file server, to protect against catastrophic worker failure.

Resilience journal files are also stored in the `--resilience-dir` directory.  Journal files' names always use the suffix `.journal`.

## Planning for catastrophic failure

Recovery from catastrophic failure requires multiple copies of the resilience directory data.  One copy of this data is maintained on the worker itself.  Any additional copies, via the I/O journal files, must be stored on a remote server.

Wallaroo is bundled with a file service, called DOS, that can store many workers' I/O journal files to guard against catastrophe.  One or more DOS servers should be installed on machines or virtual machines that are physically separate from the Wallaroo workers' machines/VMs.

The DOS server program is separate from the Wallaroo worker executable, such as `machida` or `machida3`.  When run, the DOS server listens to TCP port 9999.  The DOS server is capable of managing the I/O journals from several Wallaroo workers.

Each Wallaroo worker must be compiled with the `resilience=on` option and must use the `--run-with-resilience` flag, the `--resilience-enable-io-journal` flag, and the `--resilience-dos-server hostnameOrIpAddress:9999` flag.

## Asynchronous journal file replication

Wallaroo's I/O journal file replication uses the primary/secondary replication technique: the worker's local journal file is always the primary copy, and all remote DOS server replicas are secondary copies.  Each secondary copy is replicated asynchronously.  When the TCP connection to a remote DOS server is interrupted, a new connection is automatically reestablished when feasible.  Any data written to the primary file while disconnected from a remote DOS server is copied after a new connection is made.

If more than one remote DOS servers are used by a single Wallaroo worker, then it is quite likely that the secondary copies will not be exactly the same size.  All secondary copies will lag behind the primary copy by some number of milliseconds or even full seconds.

We know that Wallaroo a worker creates I/O journal files in strictly append-only fashion.  This append-only property makes it easy to calculate which secondary copy is the most recent or "most up-to-date" copy: the largest copy (i.e., total file size) is the most recent copy.

## Running a DOS file server

The DOS server is run with a single mandatory command line argument: a path to the local file system where the DOS server's files will be stored.  The server listens to TCP port 9999 on all network interfaces.

Example command line usage is:

    mkdir -p /var/lib/dos-server
    testing/tools/dos-dumb-object-service/dos-server.py /var/lib/dos-server

A DOS server may be used by multiple Wallaroo workers.  Each worker will store its I/O journal files in a separate subdirectory.  For example, the `initializer` worker's I/O journal files will be stored in the `/var/lib/dos-server/initializer` subdirectory.

## Running Wallaroo to use a remote DOS file server (thus enabling data redundancy)

NOTE: The Wallaroo executable (e.g., `machida` or `machida3`) compiled with the `resilience=on` option.

The following command line flags are recommended to enable data redundancy.

1. `--run-with-resilience` to enable crash & restart resiliency.

2. `--resilience-dir /path/to/dir` to specify where the local I/O journal files will be stored.

3. `--resilience-enable-io-journal` to enable I/O journalling of Wallaroo's crash resilience data.

4. `--resilience-no-local-file-io`, which disables the creation of non-I/O journal files.

5. `--dos-server host:9999` to specify where the DOS server can be contacted.  The `host` string may be a DNS hostname or IPv4 address.

## Procedure for recovering for a worker crash

See also: the [Crash Recovery in Practice section of the Crash Redundancy chapter](../resilience-crash/#recovery-in-practice)

This example assumes that each Wallaroo worker uses the argument `--resilience-dir /var/lib/wallaroo` to store its resilience data files.

1. If the worker failure was catastrophic, then (by definition) the Wallaroo worker cannot be restarted.  A replacement worker machine (or virtual machine/VM or container) must be chosen.  It is out of scope for this document to specify how a new machine, VM, or container is allocated.

2. If the worker failure was catastrophic, then copy the failed worker's I/O journal files from the DOS server's data directory, e.g., `/var/lib/dos-server/WORKER-NAME/*.journal` to a directory on the new machine/VM/container with sufficient free disk space.

3. If the Wallaroo command line flag `--resilience-no-local-file-io` was used, *or* if the worker failure was catastrophic, then the original crash resilience files must be recreated.

   * For the `app-workerName.journal` file, run the `journal-dump.py` utility.  For example, for each I/O journal file: `./testing/tools/dos-dumb-object-service/journal-dump.py /path/to/app-workerName.journal`

   * For the `app-workerName.evlog.journal` file, simply rename (or move) the file to the full path `/var/lib/wallaroo/app-workerName.evlog`

   * The `journal-dump.py` file may or may not create a `my-app.local-keys` file.  Use the `touch` utility to create the file if it does not already exist, for example, `touch /var/lib/wallaroo/app-workerName.local-keys`

   * Verify that all files in the `/var/lib/wallaroo` directory are owned by the UNIX user and group that run the Wallaroo worker processes.  Adjust using `chown`, `chgrp`, and/or `chmod` utilities as appropriate.

4. Restart the failed Wallaroo worker on the new machine/VM/container with the same command line arguments as the old-and-now-crashed Wallaroo worker.

## Scripted examples of Wallaroo worker start, stop, crash, and restart after catastrophic failure

The [resilience demos directory](https://github.com/WallarooLabs/wallaroo/tree/master/demos/resilience-demo) contains a number of shell scripts to demonstrate Wallaroo worker starting, stopping, crashing, and restarting after a catastrophic failure.  Please see the [resilience demos directory README file](https://github.com/WallarooLabs/wallaroo/tree/master/demos/resilience-demo/README.md) file for details.
