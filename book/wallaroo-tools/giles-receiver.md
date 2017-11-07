# Giles Receiver

## Overview

Giles components act as external testers for Wallaroo. Giles Receiver is used to mimic the behavior of an external sink for outgoing data from Wallaroo. Giles Receiver has the option to run in one of two ways:

- With no other commandline options given beside the listen address, it will write incoming binary data to a file named `received.txt`, with each message preceded by a timestamp of when the message was received.
- With the `--no-write/-w` flag given as a commandline argument, it will drop all incoming binary data and not write to file. This option is useful when benchmarking application speed, where the sink could potentially be a bottleneck.

### Building `giles/receiver`

If you do not already have the `wallaroo` repo, create a local copy of the repo:

```bash
git clone https://github.com/WallarooLabs/wallaroo
```

Compile the `giles-receiver` binary:

```bash
cd wallaroo/giles/receiver
make
```

## Command Line Arguments

`giles/receiver` takes several command line arguments, below are a list with accompanying notes:

* `--listen/-l` address to listen on for incoming data from Wallaroo. Must be given in the `127.0.0.1:5555` format.
* `--no-write/-w` flag to drop receive and drop incoming data.
* `--expect/-e` terminate the receiver after an expected number of messages is received.
* `--metrics/-m` Compute throughput metrics at the end of a run (requires `--expect`).

## Examples

### Listen for Wallaroo output and save to `received.txt`

```bash
receiver --listen 127.0.0.1:5555 --ponythreads=1 --ponynoblock
```

### Listen for Wallaroo output, but don't save anything (e.g. "A Very Fast Sink Receiver")

If you just want your application to run as fast as possible without spending any resources on _saving output data_, use

```bash
receiver --listen 127.0.0.1:5555 --no-write --ponythreads=1 --ponynoblock
```

## Pony Runtime Options

The following pony runtime parameters may also be useful in some situations

* `--ponythreads` limits the number of threads the pony runtime will use.
* `--ponynoblock`
* `--ponypinasio`

A common usecase is limiting `giles/receiver` to one thread, noblock, and pinning asio:

```bash
receiver --listen 127.0.0.1:5555 --ponythreads=1 --ponynoblock --ponypinasio
```

## `giles/receiver` vs. netcat

One question that comes up often is why not just use netcat for a output receiver. The reason is two-fold:

1. If the giles sender and receiver are run on the same physical machine, then their _monotonic unadjusted clock_ is synchronised, and therefore the timestamps from `giles/sender` and `giles/receiver` can be used to compute total latencies, assuming one can relate a message in `giles/sender`'s `sent.txt` to a message in `giles/receiver`'s `received.txt`.
2. While doing performance tuning, we noticed that netcat sometimes struggles to handle heavy loads. This is understandable, as it was never designed with that purpose. `giles/receiver`, on the other hand, is specifically designed to not be bottoleneck when it is used in performance tuning a Wallaroo application.

## Output File Format

Giles Receiver saves incoming messages in a binary format of the following specification:

1. Message Length: A 32-bit (4-byte) unsigned integer specifying the length of the binary message.
2. Timestamp: a 64-bit (8-byte) unsigned integer specificying the unadjusted monotonic time (in nanoseconds) at which the the message was received. This timestamp is specific to the machine that is performing this encoding and cannot be translated across machines.
3. A binary blob length `Message Length`

An example for such an entry, with a binary message of 10 bytes and the timestamp 10 is
```
'\x00\x00\x00\n\x00\x00\x00\x00\x00\x00\x00\nabcdefghij'
```

Note that you cannot trust newlines as separators in this encoding. As you can see in the encoded entry above, the character `'\n'` appears  in both the `message_length` entry `'\x00\x00\x00\n'` and in the `timestamp` entry `'\x00\x00\x00\x00\x00\x00\x00\n'`.
So care must be taken when decoding giles-receiver output files to not assume that any character separator is safe for use. Instead, the recommended way to decode these files is to treat their contents as a bytestream, and decode them one message at at time in the following manner:

1. Read the first 4 bytes and convert them from a big-endian 32-bit unsigned int to a number in your decoder.
2. Read the next 8 bytes, and if you have a use for the monotonic unadjusted nanoseconds timestamp, convert it to a number from a big-endian 64-bit unsigned integer.
3. Read `message_length` bytes and decode according to your application's `SinkEncoder` encoding scheme, if desired.
4. Save or process the message
5. GOTO 1

For decoding the output, please see [Decoding Giles Receiver Output](/book/appendix/decoding-giles-receiver-output.md).
