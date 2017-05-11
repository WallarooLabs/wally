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
```

**On Linux**:

```bash
g++ --debug -c -o build/Counter.o cpp/Counter.cpp -Wall -std=c++11 -Ihpp
```

Then on either platform, continue with:

```bash
ar rs build/libcounter.a build/Counter.o
ponyc --debug --export --output=build \
  --path=../../../../lib:../../../../lib/wallaroo/cpp_api/cpp/cppapi/build/build/lib:./build \
    counter-app
```

## Running

