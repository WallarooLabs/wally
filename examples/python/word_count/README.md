# Word count

This is an example application that receives strings of text, splits it into individual words and counts the occurrences of each word.

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Running Word Count

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module word_count`:

```bash
machida --application-module word_count --in 127.0.0.1:7010 \
  --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:6000 --data 127.0.0.1:6001 --external 127.0.0.1:5050 \
  --cluster-initializer --name worker-name --ponythreads=1
```

In a third shell, send some messages:

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file count_this.txt \
--batch-size 5 --interval 100_000_000 --messages 10000000 \
--ponythreads=1 --repeat
```

And then... watch a streaming output of words and counts appear in the listener window.

Shut down cluster once finished processing:

```bash
../../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```
