# Word Count in Go

This is an experimental Word Count application that uses a skeletal Go
API for Wallaroo. It works like the other word count examples, if you
want to seem more details you should look at them.

## Build

```bash
go build -buildmode=c-archive -o lib/libwallaroo.a word_count
stable env ponyc --debug -D autoscale
```

## Run

### Shell 1

Run a listener.

```bash
development/wallaroo/giles/receiver/receiver --ponythreads=1 --listen 127.0.0.1:7002
```

### Shell 2

Start the cluster initializer.

```bash
./word_count_with_api --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker-name --external 127.0.0.1:5050 --cluster-initializer \
  --ponynoblock --cluster-initializer
```

### Shell 3

Start the second worker.

```bash
./word_count_with_api --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --name worker-name --external 127.0.0.1:5050 --name w1 -j 127.0.0.1:6000 \
  --ponynoblock
```

### Shell 4

Send some messages.

```bash
echo -n '\x00\x00\x00\x33a b c d e f g h i j k l m n o p q r s t u v w x y z' | nc 127.0.0.1 7010
```
