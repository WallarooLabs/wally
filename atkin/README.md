# Atkin

Atkin is a Wallaroo-Python Runtime that enables a Wallaroo WActor-based
application to be written in Python.

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
clang -g -o build/python-wactor.o -c cpp/python-wactor.c
ar rvs build/libpython-wactor.a build/python-wactor.o
ponyc --debug --output=build --path=build --path=../lib/ .
```

**On Linux**:

```bash
gcc -g -o build/python-wactor.o -c cpp/python-wactor.c
ar rvs build/libpython-wactor.a build/python-wactor.o
ponyc --debug --output=build --path=build --path=../lib/ .
```

## Next Steps

### The WActor Python API

You can read up on the [WActor Python API](/book/python-wactor/api.md).

### Run Some Applications

#### Run Toy CRDT computation

See [CRDT application instructions](/examples/python-wactor/CRDT/README.md).

