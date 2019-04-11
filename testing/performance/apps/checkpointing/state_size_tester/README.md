# Checkpoint Performance Testing Application
An application for testing how checkpoint work load affects Wallaroo

## Requirements
- giles-sender
- data_receiver
- state_size_tester, with resilience enabled
- testing/tools/checkpoint_probe

## Running
1. Start receiver
    **TODO: add this, Remember to send the output to a file with `> <test_name>_output.log`**
2. Start checkpoint_probe
    ```bash
    ~/wallaroo/testing/tools/checkpoint_probe --res-dir res-data --workers 1 --output <test_name>_checkpoint_stats.log
    ```
3. Start application
    **TODO: Note that the value of `--resilience-dir` should match with the value given to `--res-dir` in (2)**
4. State warmup sender
    ```bash
    sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/giles/sender/sender \
      --host wallaroo-leader-1:7001 \
      --file ~/wallaroo/testing/performance/apps/checkpointing/state_size_test/checkpoint_perf_test_100_keys.msg \
      --interval 1_000_000 \
      --batch-size 100 \
      --binary --msg-size 12 \
      --no-write \
      --messages 1_000_000_000 \
      --ponythreads=1 --ponypinasio --ponypin --ponynoblock
    ```
5. Wait a few seconds to let thing stabilize
6. Start main sender
    ```bash
    sudo cset proc -s user -e numactl -- -C 1,17 chrt -f 80 ~/wallaroo/giles/sender/sender \
      --host wallaroo-leader-1:7001 \
      --file ~/wallaroo/testing/performance/apps/checkpointing/state_size_test/checkpoint_perf_test_100_keys.msg \
      --interval 1_000_000 \
      --batch-size 100 \
      --binary --msg-size 12 \
      --no-write \
      --messages 1_000_000_000 \
      --repeat \
      --ponythreads=1 --ponypinasio --ponypin -—ponynoblock
    ```

## Tearing down
1. Stop the application, receiver, and sender
2. Copy `<test_name>_output.log` and `<test_name>_checkpoint_stats.log` off of the test host and onto a shared access location (S3, google drive, dropbox?)
3. shut down the host and delete it if not using again.
