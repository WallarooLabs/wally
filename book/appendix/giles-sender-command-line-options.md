# `giles/sender` Command Line Options

`giles/sender` takes several command line arguments, below is a list with accompanying notes:

* `--buffy/-b` address and port combination that Wallaroo is listening on for incoming source data. Must be provided in the `127.0.0.1:8082` format.
* `--messages/-m` number of messages to send before terminating the sender.
* `--file/-f` a file with newline-separated entries from which to read entries to send.
* `--batch-size/-s` specifies the number of messages sent at every interval.
* `--interval/-i` interval at which to send a batch of messages to Wallaroo. Defaults to `5_000_000`. The value is in nanoseconds.
* `--repeat/-r` tells the sender to repeat reading the file/s as long as necessary to send the number of messages specified by `-m`.
* `--binary/-y` a flag to pass if the data source file is in binary format.
* `--u64/-u` send binary-encoded U64 values, starting from offset and incrementing by 1. The first value sent is offset+1.
* `--start-from/-v` Set the offset for use with `--u64/-u` or when `--file/-f` is not used.
* `--variable-size/-z` a flag to pass if using binary format and the binary messages have varying lengths.
* `--msg-size/-g` the size of the binary message in bytes.
* `--no-write/-w` flag to stop the `sender` from writing the messages sent to file.
* `--phone-home/-p` Dagon address. Must be provided in the `127.0.0.1:8082` format. Only used when run by Dagon.
* `--name/-n` Name to register itself with to Dagon. Only used when run by Dagon.

You may find more information about `giles/sender` in the [wallaroo-tools/giles-sender](/book/wallaroo-tools/giles-sender.md) section.

## Examples

### Send words from a file

Each line contains a single word:

```bash
# words.txt
hello
world
lorem
ipsum
sit
amet
```

Use

```bash
sender --buffy 127.0.0.1:7000 --file words.txt --messages 100 --repeat
```


### Send a sequence of numbers, encoded as strings

To send the sequence `'1', '2', '3', ..., '100'`


Use

```bash
sender --buffy 127.0.0.1:7000 --messages 100
```

### Send a sequence of numbers, encoded as big-endian U64

To send the sequence `1,2,3,...,100`

Use

```bash
sender --buffy 127.0.0.1:7000 --messages 100 --u64
```

To send the sequence `101,102,...,200`

Use

```bash
sender --buffy 127.0.0.1:7000 --messages 100 --u64 --start-from 100
```

## Pony Runtime Options

The following pony runtime parameters may also be useful in some situations

* `--ponythreads` limits the number of threads the pony runtime will use.
* `--ponynoblock`
* `--ponypinasio`
