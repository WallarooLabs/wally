# Counter

Counter is an application that keeps a running total of the values it has seen so far.

## Prerequisities

- [CPP setup instructions](/book/cpp/building.md)

## Building

```bash
mkdir build
```

**On MacOS**:

```bash
clang++ --debug -c -o build/Counter.o cpp/Counter.cpp -Wall -std=c++11 -Ihpp
ar rs build/libcounter.a build/Counter.o
ponyc --linker c++ --debug --export --output=build \
  --path=../../../../lib:../../../../cpp_api/cpp/cppapi/build/build/lib:./build:../../../../cpp_api \
    counter-app
```

**On Linux**:

```bash
g++ --debug -c -o build/Counter.o cpp/Counter.cpp -Wall -std=c++11 -Ihpp
ar rs build/libcounter.a build/Counter.o
ponyc --linker c++ --debug --export --output=build \
  --path=../../../../lib:../../../../cpp_api/cpp/cppapi/build/build/lib:./build:../../../../cpp_api \
    counter-app
```

## Generating Data

The Counter-app application takes the following input:
1. a 16-bit uint specifying the length of the rest of the message
2. a 16-bit uint specifying how many numbers follow
3. as many 32-bit uints as were specified in (2).

A data generator is bundled with the application:

```bash
cd data_gen
python data_gen.py 10000
```

Will generate 10,000 messages with 10 32-bit uints each.

## Running

You will need five separate shells to run this application. Open each shell and go to the `examples/cpp/counter-app` directory.

### Shell 1: Metrics UI
    ```bash
    docker start mui
    ```

You can verify it started up correctly by visiting [http://localhost:4000](http://localhost:4000).

If you need to restart the UI, run:

```bash
docker restart mui
```

When it's time to stop the UI, run:

```bash
docker stop mui
```

If you need to start the UI after stopping it, run:

```bash
docker start mui
```

### Shell 2: Data Receiver

Start a listener with using `nc`

```bash
nc -l 127.0.0.1 7002 > counter.out
```

### Shell 3: Counter-app

Start the application

```bash
./build/counter-app --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
  --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
  --worker-name worker-name --cluster-initializer --ponythreads=1 \
  --ponynoblock
```

### Shell 4: Sender

Start sending data

```bash
../../../../giles/sender/sender --host 127.0.0.1:7010 --file data_gen/numbers.msg \
  --batch-size 50 --interval 10_000_000 --binary --msg-size 44 --repeat \
  --ponythreads=1 --ponynoblock --messages 1000000 --no-write
```

## Shutdown

### Shell 5: Shutdown

You can shut down the cluster with this command at any time:

```bash
cd ~/wallaroo-tutorial/wallaroo/utils/cluster_shutdown
./cluster_shutdown 127.0.0.1:5050
```

You can shut down Giles Sender and Giles Receiver by pressing Ctrl-c from their respective shells.

You can shut down the Metrics UI with the following command:

```bash
docker stop mui
```
