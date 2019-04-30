# Running a manual log rotation test using this app

## Build

```bash
make clean
make build debug=true resilience=on
make build-utils-data_receiver build-giles-sender
```

## Run

Receiver:

```bash
../../../../utils/data_receiver/data_receiver --listen 127.0.0.1:21000 --framed
```

Initializer:

```bash
mkdir -p res-dataA
rm res-data/*
./sequence_window \
  --run-with-resilience \
  --in "Sequence Window"@127.0.0.1:20000 \
  --out 127.0.0.1:21000 \
  --metrics 127.0.0.1:35000 \
  --resilience-dir res-data \
  --name initializer  \
  --worker-count 2 \
  --data 127.0.0.1:20003 \
  --external 127.0.0.1:20004 \
  --cluster-initializer  \
  --control 127.0.0.1:20002   \
  --ponythreads=1 \
  --ponypinasio \
  --ponynoblock
  --log-rotation \
  --event-log-file-size 50000
```

Worker:

```
./sequence_window \
  --run-with-resilience \
  --out 127.0.0.1:21000 \
  --metrics 127.0.0.1:35000 \
  --resilience-dir res-data \
  --name worker  \
  --control 127.0.0.1:20002   \
  --my-data 127.0.0.1:20103 \
  --my-control 127.0.0.1:20102   \
  --external 127.0.0.1:20104 \
  --ponythreads=1 \
  --ponypinasio \
  --ponynoblock \
  --log-rotation \
  --event-log-file-size 50000
```

Sender:

```bash
../../../../giles/sender/sender -h 127.0.0.1:20000 -s 100 -i 50_000_000 \
--ponythreads=1 -y -g 12 -w -u -m 10000
```
