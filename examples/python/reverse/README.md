# Reverse

## About The Application

This is an example application that receives strings as input and outputs the reversed strings.

### Input

The inputs of the "Reverse" application are strings encoded in the [source message framing protocol](/book/appendix/writing-your-own-feed.md#source-message-framing-protocol). Here's an example input message, written as a Python string:

```
"\x00\x00\x00\x05hello"
```

`\x00\x00\x00\x05` -- four bytes representing the number of bytes in the payload

`hello` -- the string `"hello"`

### Output

The outputs of the application are strings followed by newlines. Here's an example output message, written as a Python string:

`olleh\n` -- the string `"olleh"` (`"hello"` reversed)

### Processing

The `Decoders`'s `decode(...)` method creates a string from the value represented by the payload. The string is then sent to the `Reverse` computation where it is reversed. The reversed string is then sent to `Encode`'s `encode(...)` method, where a newline is appended to the string.

## Running Reverse

In order to run the application you will need Machida, Giles Sender, Giles Receiver, and the Cluster Shutdown tool. To build them, please see the [Linux](/book/linux-setup.md) or [Mac OS](/book/macos-setup.md) setup instructions.

You will need three separate shells to run this application. Open each shell and go to the `examples/python/reverse` directory.

### Shell 1

Run `nc` to listen for the output messages:

```bash
nc -l 127.0.0.1 7002
```

### Shell 2

Set `PYTHONPATH` to refer to the current directory (where `celsius.py` is) and the `machida` directory (where `wallaroo.py` is). Set `PATH` to refer to the directory that contains the `machida` executable. Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

Run `machida` with `--application-module reverse`:

```bash
machida --application-module reverse --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponythreads=1
```

### Shell 3

Send some messages:

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file words.txt \
  --batch-size 5 --interval 100_000_000 --messages 150 --repeat \
  --ponythreads=1
```

## Reading the Output

The output will be printed to the console in the first shell. Each line should be the reverse of a word found in the `words.txt` file.

## Shutdown

You can shut down the cluster with this command once processing has finished:

```bash
../../../utils/cluster_shutdown/cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender by pressing `Ctrl-c` from its shell.
