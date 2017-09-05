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

Return to the `counter-app` app directory for the [running](#running) instructions.

## Running

Start the Metrics UI if it isn't already running:
    ```bash
    docker start mui
    ```

In a separate shell each:

1. Start a listener with Giles Receiver
    ```bash
    nc -l 127.0.0.1 7002 > counter.out
    ```
2. Start the application
    ```bash
    ./build/counter-app --in 127.0.0.1:7010 --out 127.0.0.1:7002 \
      --metrics 127.0.0.1:5001 --control 127.0.0.1:6000 --data 127.0.0.1:6001 \
      --worker-name worker-name --cluster-initializer --ponythreads=1
    ```
3. Start sending data
    ```bash
     ../../../../giles/sender/sender --host 127.0.0.1:7010 --file data_gen/numbers.msg \
       --batch-size 50 --interval 10_000_000 --binary --msg-size 44 --repeat \
       --ponythreads=1 --messages 1000000
    ```
