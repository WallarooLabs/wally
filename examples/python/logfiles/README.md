# Log Files

This is an example of a stateful application that counts the occurrences of return codes in Apache logs, per day, using non-native event windowing. This example is discussed in the [Non-native event-driven windowing in Wallaroo](http://blog.wallarolabs.com/) blog post.

You will need a working [Wallaroo Python API](/book/python/intro.md).

## Running Log Files

In a shell, start up the Metrics UI if you don't already have it running:

```bash
docker start mui
```

In a shell, set up a listener:

```bash
nc -l 127.0.0.1 7002 > logfiles.out
```

In another shell, set up your environment variables if you haven't already done so. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module logfiles`:

```bash
machida --application-module logfiles --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name \
  --ponythreads=1
```

In a third shell, send the log files using the specialised sender:

```bash
for f in day_*.log; do python sender.py 127.0.0.1:8002 $f; done
```

## Reading the Output

The output is binary data, formatted as a 4-byte message length header, followed by a string-serialised json representation of the return code counts.

You can read it with the following code stub:

```python
import struct


with open('logfiles.out', 'rb') as f:
    while True:
        try:
            length = struct.unpack('>I', f.read(4))
            print f.read(length)
        except:
            break
```
