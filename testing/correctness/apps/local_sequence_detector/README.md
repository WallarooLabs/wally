Run Data Receiver to listen for TCP output on `127.0.0.1` port `7002`:

```bash
./data_receiver --ponythreads=1 --ponynoblock --listen 127.0.0.1:7002
```

Run the application:

Initializer:
```bash
./local_sequence_detector --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --name initializer --external 127.0.0.1:5050 --cluster-initializer \
  --ponynoblock --worker-count 2
```

Worker2:
```bash
./local_sequence_detector --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 \
  --my-control 127.0.0.1:6002 --my-data 127.0.0.1:6003 \
  --name w2 --external 127.0.0.1:5050 \
  --ponynoblock
```
