# Machida

Machida is a Wallaroo-Python Runtime that enables a Wallaroo application to be written in Python.

## Requirements
- clang >=3.5 on MacOS or gcc >=5 on Linux
- python-dev
- sendence-ponyc
- giles-sender

You will also need your environment to be [set up with a working
Wallaroo](/book/getting-started/setup.md).

## Build

Create the `build` directory if it doesn't already exist.

```
mkdir build
```

Build the program.

**On MacOS**:

```bash
clang -g -o build/python-wallaroo.o -c cpp/python-wallaroo.c
ar rvs build/libpython-wallaroo.a build/python-wallaroo.o
ponyc --debug --output=build --path=build --path=../lib/ .
```

**On Linux**:

```bash
gcc -g -o build/python-wallaroo.o -c cpp/python-wallaroo.c
ar rvs build/libpython-wallaroo.a build/python-wallaroo.o
ponyc --debug --output=build --path=build --path=../lib/ .
```

## Next Steps

### The Wallaroo Python API

You can read up on the [Wallaroo Python API](/book/python/api.md).

### Run Some Applications

#### Run Reverse Word (stateless computation)

See [Reverse application instructions](/examples/python/reverse/README.md).

#### Run Alphabet (stateful computation)

See [Alphabet application instructions](/examples/python/alphabet/README.md).

#### Run Marketspread (stateful computation)

See [Market Spread application instructions](/examples/python/market_spread/README.md)
