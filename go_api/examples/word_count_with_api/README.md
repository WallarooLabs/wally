# Word Count in Go

This is an experimental Word Count application that uses the Wallaroo
Go API. It works like the other word count examples, if you want to
seem more details you should look at them.

## Build

You'll need to have the GNU `realpath` utility installed. If you are on MacOS, install GNU coreutils:

```bash
brew install coreutils
```

On debian based systems you should be able to:

```bash
sudo apt-get install realpath
```

To build the word count binary:

```bash
export GOPATH="$(realpath .)/go:$(realpath ../../go)"
go build -buildmode=c-archive -o lib/libwallaroo.a word_count
stable fetch
stable env ponyc -D autoscale
```

Make sure that you've built Giles sender and receiver. They are
required for the `demo_sender` and `demo_receiver` scripts.

## Run

### Shell 1

Run a listener.

```bash
./demo_receiver
```

### Shell 2

Start the cluster initializer.

```bash
./worker1
```

### Shell 3

Send some messages.

```bash
./demo_sender
```

### Shell 4

Start the second worker.

```bash
./worker2
```

### Shell 5

Start the second worker.

```bash
./worker3
```
