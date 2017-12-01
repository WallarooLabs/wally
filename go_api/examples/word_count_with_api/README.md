# Word Count in Go

This is an experimental Word Count application that uses the Wallaroo
Go API. It works like the other word count examples, if you want to
seem more details you should look at them.

## Build

Make sure that you've built Giles sender and receiver. They are
required for the `demo_sender` and `demo_receiver` scripts.

Then build the application.

```bash
export GOPATH="$(realpath .)/go:$(realpath ../../go)"
go build -buildmode=c-archive -o lib/libwallaroo.a word_count
stable fetch
stable env ponyc -D autoscale
```

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

Start the second worker.

```bash
./worker2
```

### Shell 4

Start the second worker.

```bash
./worker3
```

### Shell 5

Send some messages.

```bash
./demo_sender
```
