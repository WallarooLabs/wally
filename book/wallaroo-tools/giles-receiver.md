# Giles Receiver

## Overview

Giles components act as external testers for Wallaroo. Giles Receiver is used to mimic the behavior of an external sink for outgoing data from Wallaroo. Giles Receiver has the option to run in one of two ways:

- With no other commandline options given, it will write incoming binary data to file, preceded by a timestamp of when the message was received. For example, `./giles/receiver -l 127.0.0.1:5555` will write any data received on port 5555.

- With the `--no-write/-w` flag given as a commandline argument, it will drop all incoming binary data and not write to file. For example, `./giles/receiver -l 127.0.0.1:5555 -w` will receive and drop any data received on port 5555.

### Getting Wallaroo

If you do not already have the `wallaroo` repo, create a local copy of the repo:

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

`giles/receiver` takes several command line arguments, below are a list with accompanying notes:

`--listen/-l` address to listen on for incoming data from Wallaroo. Must be given in the `127.0.0.1:5555` format.

`--no-write/-w` flag to drop receive and drop incoming data.

`--phone-home/-p` Dagon address. Must be provided in the `127.0.0.1:8082` format.

`--name/-n` Name to register itself with to Dagon.
