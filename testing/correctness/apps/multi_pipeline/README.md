# Multi-Sink Celsius

This is an example of a stateless application that takes a floating point Celsius value and sends out a floating point Fahrenheit value.

The pipeline is duplicated to test multi-sink functionality with a separate pipeline per sink.

## Running Multi-Pipeline Celsius

1. Start two listeners

```bash
nc -l 127.0.0.1 7002 > multi_pipeline_1.out
nc -l 127.0.0.1 7003 > multi_pipeline_2.out
```

2. Single Worker: Start the application

```bash
./multi_pipeline \
  --in "Celsius Conversion0"@127.0.0.1:7010,"Celsius Conversion1"@127.0.0.1:7011 \
  --out 127.0.0.1:7002,127.0.0.1:7003 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 --cluster-initializer
```

3. Two Workers: Start the application

```bash
./multi_pipeline \
  --in "Celsius Conversion0"@127.0.0.1:7010,"Celsius Conversion1"@127.0.0.1:7011 \
  --out 127.0.0.1:7002,127.0.0.1:7003 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 -w 2 --cluster-initializer

./multi_pipeline \
  --in "Celsius Conversion0"@127.0.0.1:7020,"Celsius Conversion1"@127.0.0.1:7021 \
  --out 127.0.0.1:7002,127.0.0.1:7003 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --name worker2
```

4. Three Workers: Start the application

```bash
./multi_pipeline \
  --in "Celsius Conversion0"@127.0.0.1:7010,"Celsius Conversion1"@127.0.0.1:7011 \
  --out 127.0.0.1:7002,127.0.0.1:7003 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --data 127.0.0.1:12501 -w 3 --cluster-initializer

./multi_pipeline \
  --in "Celsius Conversion0"@127.0.0.1:7020,"Celsius Conversion1"@127.0.0.1:7021 \
  --out 127.0.0.1:7002,127.0.0.1:7003 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --name worker2

./multi_pipeline \
  --in "Celsius Conversion0"@127.0.0.1:7030,"Celsius Conversion1"@127.0.0.1:7031 \
  --out 127.0.0.1:7002,127.0.0.1:7003 --metrics 127.0.0.1:5001 \
  --control 127.0.0.1:12500 --name worker3
```

3. Start two senders

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file celsius.msg \
  --batch-size 5 --interval 100_000_000 --messages 150 --binary \
  --variable-size --repeat --ponythreads=1 --no-write

../../../../giles/sender/sender --host 127.0.0.1:7011 --file celsius.msg \
  --batch-size 5 --interval 100_000_000 --messages 150 --binary \
  --variable-size --repeat --ponythreads=1 --no-write
```
