# Resilience

Wallaroo is designed with built-in resilience. However, since the operations involved with maintaining resilience can impact performance, this mode is off by default. To enable resilience in a Wallaroo application, the binary needs to be built with `-D resilience` if using the `ponyc` compiler directly, or with `resilience=on` if using our Makefile build system (as with `Machida`).

## How Does Wallaroo Implement Resilience

Wallaroo's resilience is based on the Chandy-Lamport snapshotting algorithm that minimizes the impact of checkpointing on processing in-flight messages. Each worker maintains a resilience file, where it periodically saves a snapshot of its latest state. A checkpoint represents a consistent recovery line—a specific generation of individual worker snapshots. This means that when a failed worker recover, we can roll back the states in the cluster to the last checkpoint and begin processing again with the guarantee that all state in the system reflects a causally consistent history. The interval between checkpoints is configurable with the `--time-between-checkpoints` command line parameter (in nanoseconds).

Since recovery involves a rollback to the last successful checkpoint, any data that was processed _after_ that checkpoint will have to be resent by the sources.

## Recovery in Practice

When a crashed worker is restarted, if it can find its resilience files in the path specified by `--resilience-dir`, it will automatically start the recovery process. The simplest way to do this is to rerun the worker using the same command it was originally run with.

For example, if we were running the bundled Python example [word_count_with_dynamic_keys](https://github.com/WallarooLabs/wallaroo/tree/master/examples/python/word_count_with_dynamic_keys/), this might look something like:

### Running the resilience example

In order to run the example you will need Machida with resilience enabled, Giles Sender, Data Receiver, and the Cluster Shutdown tool. If you're using our Docker or Vagrant installation, these should already be set up.

If you built Wallaroo from source, please run the following commands:

    cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/
    make build-machida-all resilience=on
    cp machida/build/machida bin/machida-resilience

If you haven't yet set up wallaroo, please visit our [setup](https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html) instructions to get started.

### Running the example

The rest of the example should be run in the `examples/python/word_count_with_dynamic_keys` directory in the Wallaroo repository.
You will need 4 shells to run this example.

1. Create the path where the workers will save their resilience snapshots.

        mkdir -p /tmp/resilience-dir

2. Shell 1: Start a data receiver

        cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/word_count_with_dynamic_keys
        data_receiver --listen 127.0.0.1:7002 | tee received.txt

3. Shell 2: Start initializer

        cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/word_count_with_dynamic_keys
        machida-resilience --application-module word_count_with_dynamic_keys \
          --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
          --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
          --data 127.0.0.1:6001 --external 127.0.0.1:5050 \
          --name initializer --cluster-initializer --worker-count 2 \
          --resilience-dir /tmp/resilience-dir \
          --ponythreads=1 --ponynoblock \
          | tee initializer.log

4. Shell 3: Start worker

        cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/word_count_with_dynamic_keys
        machida-resilience --application-module word_count_with_dynamic_keys \
          --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
          --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
          --my-data 127.0.0.1:6003 --my-control 127.0.0.1:6002 \
          --external 127.0.0.1:5051 \
          --name worker1 \
          --resilience-dir /tmp/resilience-dir \
          --ponythreads=1 --ponynoblock \
          | tee worker1.log

5. Shell 4: Start sender

        cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/examples/python/word_count_with_dynamic_keys
        sender --host 127.0.0.1:7010 --file count_this.txt --batch-size 5 \
          --interval 1_000_000_000 --messages 10000000 --ponythreads=1 \
          --ponynoblock --repeat --no-write

6. Wait a few seconds for the internal states to update and for some checkpoints to complete
7. Shell 4: Stop the sender (`Ctrl-C`)
8. Shell 4: Kill the worker to simulate a crash (using SIGKILL)

        pkill -f -KILL machida.*worker1

9. Shell 4: Send some data directly to our data receiver to mark in the sink where the crash occurred (for demonstration purposes)

        echo '<<CRASH-and-RECOVER>>' | nc -q1 127.0.0.1 7002

10. Shell 3: Restart worker1 with the same command we used above, but save its log output to a new file

        machida-resilience --application-module word_count_with_dynamic_keys \
          --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
          --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
          --my-data 127.0.0.1:6003 --my-control 127.0.0.1:6002 \
          --external 127.0.0.1:5051 \
          --name worker1 \
          --resilience-dir /tmp/resilience-dir \
          --ponythreads=1 --ponynoblock \
          | tee worker1.recovered.log

11. Shell 4: Restart the sender

        sender --host 127.0.0.1:7010 --file count_this.txt --batch-size 5 \
          --interval 1_000_000_000 --messages 10000000 --ponythreads=1 \
          --ponynoblock --repeat --no-write

12. Shell 4: Let things run for a few more seconds before shutting down the sender (`Ctrl-C`), and then shut down the cluster with the `cluster_shutdown` tool.

        cluster_shutdown 127.0.0.1:5050


### Verifying that recovery was successful

To verify that recovery was successful, we turn first to the recovering worker's log file, and look for the text

      Recovering from recovery files!
      Attempting to recover...

immediately after the license notifications.
To see that recovery was successful, we next look for the text

        |~~ - Recovery COMPLETE - ~~|
        ~~~Resuming message processing.~~~
        |~~ INIT PHASE III: Application is ready to work! ~~|

This informs us that the worker has recovered successfully and that the cluster is now ready to process incoming data again.

To further see that the state was indeed recovered, we can look at the data received by the sink, in `received.txt`. In this case, we will look at a particular key, `amendment`, but you can do the same with any of the other keys:

        amendment => 11
        ...
        <<CRASH-and-RECOVER>>
        ...
        amendment => 12
        ...
