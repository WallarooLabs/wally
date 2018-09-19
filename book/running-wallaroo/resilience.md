# Resilience

Wallaroo is designed with built-in resilience. However, since the operations involved with maintaining resilience can impact performance, this mode is off by default. To enable resilience in a Wallaroo application, the binary needs to be built with `-D resilience` if using the `ponyc` compiler directly, or with `resilience=on` if using our Makefile build system (as with `Machida`).

## How Does Wallaroo Implement Resilience

Wallaroo's resilience is based on the Chandy-Lamport snapshotting algorithm that minimizes the impact of checkpointing on processing in-flight messages. A checkpoint represents a consistent recovery line. This means that when a failed worker recovers, we can roll back to the last checkpoint and begin processing again with the guarantee that all state in the system reflects a causally consistent history. The interval between checkpoints is configurable with the `--time-between-checkpoints` command line parameter (in nanoseconds).

Since recovery involves a rollback to the last successful checkpoint, any data that was processed _after_ that checkpoint will have to be resent by the sources.

## Recovery in Practice

When a crashed worker is restarted, if it can find its resilience files in the path specified by `--resilience-dir`, it will automatically start the recovery process. The simplest way to do this is to rerun the worker using the same command it was originally run with.

For example, if we were running the bundle Python example [word_count](/examples/python/word_count_with_dynamic_keys/README.md), this might look something like:

1. Start a data receiver
    data_receiver --listen 127.0.0.1 7000 | tee received.txt
2. Start initializer
    machida --application-module word_count_with_dynamic_keys --in 127.0.0.1:7010 \
    --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
    --data 127.0.0.1:6001 --name worker-name --external 127.0.0.1:5050 \
    --cluster-initializer --ponythreads=1 --ponynoblock \
    --resilience-dir /tmp/res-dir/wc \
    | tee initializer.log
3. Start worker
    machida --application-module word_count_with_dynamic_keys --in 127.0.0.1:7010 \
    --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --join 127.0.0.1:6000 \
    --my-data 127.0.0.1:6003 --my-control 127.0.0.1:6002 --name worker1 \
    --external 127.0.0.1:5051 --ponythreads=1 --ponynoblock \
    --resilience-dir /tmp/res-dir/wc \
    | tee worker1.log
4. Start sender
    sender --host 127.0.0.1:7010 --file count_this.txt --batch-size 5 \
    --interval 1_000_000_000 --messages 10000000 --ponythreads=1 \
    --ponynoblock --repeat --no-write
5. Wait a few seconds for the internal states to update and for some checkpoints to complete
6. Stop the sender (`ctrl-C`)
7. Kill the worker to simulate a crash (using SIGKILL)
    pkill -f -KILL machida.*worker1
8. Send some data directly to our data receiver to mark in the sink where the crash occurred (for demonstration purposes)
    echo '<<CRASH-and-RECOVER>>' | nc -q1 127.0.0.1 7002
8. Restart worker1 with the same command we used above, but save its log output to a new file
    machida --application-module word_count_with_dynamic_keys --in 127.0.0.1:7010 \
    --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 --join 127.0.0.1:6000 \
    --my-data 127.0.0.1:6003 --my-control 127.0.0.1:6002 --name worker1 \
    --external 127.0.0.1:5051 --ponythreads=1 --ponynoblock \
    --resilience-dir /tmp/res-dir/wc \
    | tee worker1.recovered.log
9. Restart the sender
    sender --host 127.0.0.1:7010 --file count_this.txt --batch-size 5 \
    --interval 1_000_000_000 --messages 10000000 --ponythreads=1 \
    --ponynoblock --repeat --no-write
10. Let things run for a few more seconds before shutting everything down.

To verify that recoery was successful, we turn first to the recovering worker's log file, and look for the text
    Recovering from recovery files!
    Attempting to recover...
immediately after the license notifications.
To see that recovery was successful, we next look for the text
    |~~ - Recovery COMPLETE - ~~|
    ~~~Resuming message processing.~~~
    |~~ INIT PHASE III: Application is ready to work! ~~|
This informs us that the worker has recovered successfully and that the cluster is now ready to process incoming data again.

To further see that the state was indeed recovered, we can look at the data received by the sink, in `received.txt`:
    amendment => 11
    ...
    <<CRASH-and-RECOVER>>
    ...
    amendment => 12
    ...
