# Alphabet

Alphabet application is meant for use in testing multi-worker features that require more than the 2 partitions available in sequence window.


## build
```
make build-testing-correctness-apps-alphabet build-utils-cluster_shrinker build-utils-data_receiver build-giles-all
```

## Start 1, Join 2, Shrink 3->2, Start sender, validate.

Sink
```
nc -l 127.0.0.1 7002 > received.txt
```

Metrics
```
../../../../utils/data_receiver/data_receiver --listen 127.0.0.1:5001 --no-write
```

Initializer
```
./alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --external 127.0.0.1:5050 \
  --cluster-initializer --ponynoblock --ponythreads=1
```

Joining:

Worker 1/2
```
./alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --my-control 127.0.0.1:12502 --my-data 127.0.0.1:12503 --join 127.0.0.1:12500 \
  --worker-count 2 --name worker1 \
  --ponynoblock --ponythreads=1
```

Worker 2/2
```
./alphabet --in 127.0.0.1:7010 --out 127.0.0.1:7002 --metrics 127.0.0.1:5001 \
  --my-control 127.0.0.1:12504 --my-data 127.0.0.1:12505 --join 127.0.0.1:12500 \
  --name worker2 --worker-count 2 \
  --ponynoblock --ponythreads=1
```

Cluster shrinker 3->2
```
../../../../utils/cluster_shrinker/cluster_shrinker --external 127.0.0.1:5050 --workers worker2
```

Sender
```
../../../../giles/sender/sender --host 127.0.0.1:7010 \
  --file input.msg --batch-size 5 --interval 10_000_000 \
  --messages 1000 --binary --variable-size --repeat --ponythreads=1 \
  --ponynoblock --no-write
```

Validate
```
python validate.py --expected output.json --repetitions 1 --output received.txt
```
