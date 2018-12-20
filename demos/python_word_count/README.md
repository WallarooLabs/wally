# Python Word Count Autoscale Demo

This is an example application that receives strings of text, splits it into individual words and counts the occurrences of each word. Contains commands to allow you to autoscale up to 3 worker cluster, starting from 1.

You will need a working [Wallaroo Python API](https://docs.wallaroolabs.com/python-tutorial/).

## Running Word Count

Open 5 shells and go to the `demos/python_word_count` directory. In each one, run `source environment`.

### Shell 1

Run the receiver.

```bash
./demo_receiver
```

### Shell 2

Run worker 1.

```bash
./worker1
```

### Shell 3

Run the sender

```bash
./demo_sender
```

### Shell 4

Run worker 2.

```bash
./worker2
```

### Shell 5

Run worker 3.

```bash
./worker3
```

## Running Word Count (full)

In a shell, set up a listener:

```bash
../../utils/data_receiver/data_receiver --framed --ponythreads=1 --listen 127.0.0.1:7002
```
In another shell, export the current directory and `wallaroo.py` directories to `PYTHONPATH`:

In another shell, set up your environment variables if you haven't already done so. You should export the location of `wallaroo.py` and `word_count.py`

Run `machida` with `--application-module word_count`:

```bash
machida --application-module word_count --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --cluster-initializer --ponythreads=1
```

In a third shell, send some messages:

```bash
../../giles/sender/sender --host 127.0.0.1:7010 --file bill_of_rights.txt \
--batch-size 5 --interval 100_000_000 --messages 10000000 \
--ponythreads=1 --repeat
```

And then... watch a streaming output of words and counts appear in the listener window.

To add additional workers, you can use the following commands to demonstrate autoscaling.

Worker 2:

```bash
machida --application-module word_count --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --name worker2 --ponythreads=1 -j 127.0.0.1:6000
```

Worker 3:

```bash
machida --application-module word_count --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --name worker3 --ponythreads=1 -j 127.0.0.1:6000
```
