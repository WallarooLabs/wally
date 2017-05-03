# Giles Sender

## Overview

Giles components act as external testers for Wallaroo. Giles Sender is used to mimic the behavior of an incoming data source. Giles Sender sends data to Wallaroo in one of four ways:

- With no other commandline options given, it will send string representations of integers, starting with `1` and increasing by `1` with each new message. For example, `./giles/sender -b 127.0.0.1:8081 -m 100` will send messages containing string representations of the numbers `1` through `100`.
- With a file name given as the `--file/-f` argument it will send each line of the given file as a message. For example, `./giles/sender -b 127.0.0.1:8081 -m 100 -f war-and-peace.txt` will send messages containing each of the first 100 lines of the file `war-and-peace.txt`.
- With a file name given as the `--file/-f` argument and binary format specified with `--binary/-y` and every message is 24 bytes, specified with `--msg-size/-g`, it will send every 24 bytes of the given file as a message. For example, `./giles/sender -b 127.0.0.1:8081 -m 100 -f binary-data-file.txt -y -g 24` will send every 24 bytes until it has sent 100 messages
- With a file name given as the `--file/-f` argument and binary format specified with `--binary/-y` and variable message lengths specified with `--variable-size/-z`, it will read 4 bytes to get the message size, send that message and repeat. For example, `./giles/sender  127.0.0.1:8081 -m 100 -f binary-data-file.txt -y -z` will initially read a 4 byte header, send that message and repeat until it has sent 100 messages.

### Getting Wallaroo

If you do not already have the `wallaroo` repo, create a local copy:

```bash
git clone https://github.com/sendence/wallaroo
```

## Compiling

To compile the `giles-sender` binary:

```bash
cd wallaroo
stable env ponyc
```

## Command Line Arguments

`giles/sender` takes several command line arguments, below is a list with accompanying notes:

`--buffy/-b` address and port combination that Wallaroo is listening on for incoming source data. Must be provided in the `127.0.0.1:8082` format.

`--messages/-m` number of messages to send before terminating the sender.

`--batch-size/-s` specifies the number of messages sent at every interval.

`--interval/-i` interval at which to send a batch of messages to Wallaroo. Defaults to `5_000_000`.

`--repeat/-r` tells the sender to repeat reading the file/s as long as necessary to send the number of messages specified by `-m`.

`--binary/-y` a flag to pass if the data source file is in binary format.

`--variable-size/-z` a flag to pass if using binary format and the binary messages have varying lengths.

`--msg-size/-g` the size of the binary message in bytes.

`--no-write/-w` flag to stop the `sender` from writing the messages sent to file.

`--phone-home/-p` Dagon address. Must be provided in the `127.0.0.1:8082` format.

`--name/-n` Name to register itself with to Dagon.
