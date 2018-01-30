# Market Spread in Go

This is the Market Spread application in Go.

## Build

```bash
export GOPATH="$(realpath .)/go:$(realpath ../../go)"
go build -buildmode=c-archive -o lib/libwallaroo.a market_spread
stable fetch
stable env ponyc -D autoscale
```

## Run Single Worker

### Shell 1

Run a listener.

```bash
../../../giles/receiver/receiver --ponythreads=1 --listen 127.0.0.1:7002
```

### Shell 2

Start the worker.

```bash
./market_spread --in 127.0.0.1:7010,127.0.0.1:7011 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker1 --external 127.0.0.1:5050 --cluster-initializer \
  --ponynoblock
```

### Shell 3

Send the initial market data.

```bash
../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 -m 10000000000 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

Send new market data.

```bash
../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
  -s 150 -i 2_500_000 -m 10000000000 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write -r
```

### Shell 4

Send the order data.

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file \
  ../../../testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
  -s 150 -i 5_000_000 --messages 10000000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 57 --no-write -r
```

## Run Multi-Worker

### Shell 1

Run a listener.

```bash
../../../giles/receiver/receiver --ponythreads=1 --listen 127.0.0.1:7002
```

### Shell 2

Start the first worker.

```bash
./market_spread --in 127.0.0.1:7010,127.0.0.1:7011 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name worker1 --external 127.0.0.1:5050 --cluster-initializer \
  --ponynoblock
```

### Shell 3

Start the second worker.

```bash
./market_spread --in 127.0.0.1:7010,127.0.0.1:7011 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000  \
  --name worker2 --join 127.0.0.1:6000 --ponynoblock
```

### Shell 4

Start the third worker.

```bash
./market_spread --in 127.0.0.1:7010,127.0.0.1:7011 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000  \
  --name worker3 --join 127.0.0.1:6000 --ponynoblock
```

### Shell 5

Send the initial market data.

```bash
../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 -m 10000000000 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

Send new market data.

```bash
../../../giles/sender/sender --host 127.0.0.1:7011 --file \
  ../../../testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg \
  --batch-size 20 --interval 100_000_000 -m 10000000000 --binary \
  --ponythreads=1 --ponynoblock --msg-size 46 --no-write
```

### Shell 6

Send the order data.

```bash
../../../giles/sender/sender --host 127.0.0.1:7010 --file \
  ../../../testing/data/market_spread/orders/350-symbols_orders-fixish.msg \
  --batch-size 20 --interval 100_000_000 --messages 1000000 --binary \
  --repeat --ponythreads=1 --ponynoblock --msg-size 57 --no-write
```
