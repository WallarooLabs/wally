# `giles/receiver` Command Line Options

`giles/receiver` takes several command line arguments, below are a list with accompanying notes:

* `--listen/-l` address to listen on for incoming data from Wallaroo. Must be given in the `127.0.0.1:5555` format.
* `--no-write/-w` flag to drop receive and drop incoming data.
* `--phone-home/-p` Dagon address. Must be provided in the `127.0.0.1:8082` format. This is only used when `giles/receiver` is run by Dagon.
* `--name/-n` Name to register itself with to Dagon. This is only used when `giles/receiver` is run by Dagon.


You may find more information about `giles/receiver` in the [wallaroo-tools/giles-receiver](/book/wallaroo-tools/giles-receiver.md) section.

## Examples

### Listen for Wallaroo output and save to `received.txt`

```bash
receiver --listen 127.0.0.1:5555
```

### Listen for Wallaroo output, but don't save anything (e.g. "A Very Fast Sink Receiver")

If you just want your application to run as fast as possible without spending any resources on _saving output data_, use

```bash
receiver --listen 127.0.0.1:5555 --no-write
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
