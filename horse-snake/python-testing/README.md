# This Terrible Little Program

This project is for some experiments that bridge between Pony and
Python via C bridge functions.

## Building and Running

This builds the C library and then compiles the Python program:

```
mkdir build
clang -g -o build/mypython.o -c cpp/mypython.c
ar rvs build/libmypython.a build/mypython.o
ponyc --debug --output=build --path=build .
```

The program loads a Python module defined in a file in the current
directory. In order for the interpreter to find that file, you must
set `PYTHONPATH` to include the current directory:

```
export PYTHONPATH=.
```

Once you've done this you can run the program:

```
build/python-testing
```

You should see some text printed out and the program should not segfault.
