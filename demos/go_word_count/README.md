# Go Word Count Autoscale Demo

This is an example application that receives strings of text, splits it into individual words and counts the occurrences of each word. Contains commands to allow you to autoscale up to 3 worker cluster, starting from 1.

You will need a working [Wallaroo Go API](/book/go/api/intro.md).

## Build Word Count

```bash
make
```

## Running Word Count

Open 5 shells and go to the `demos/go_word_count` directory.

### Shell 1

Run the receiver.

```bash
./demo_receiver
```

### Shell 2

Run worker 1.

```bash
./worker1
```

### Shell 3

Run the sender

```bash
./demo_sender
```

### Shell 4

Run worker 2.

```bash
./worker2
```

### Shell 5

Run worker 3.

```bash
./worker3
```
