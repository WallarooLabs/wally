# Building A Wallaroo C++ Application

## Setting up Wallaroo

If you have not already done so, please follow the [directions for setting up Wallaroo](/book/getting-started/setup.md).

## Additional Requirements

Installation of the Wallaroo C++ API requires some additional software:

* `cmake` version 3.5.0 or higher -- This should be available from your
package manager.

* `spdlog` version 0.12.0 -- available
  [here](https://github.com/gabime/spdlog). Please follow the
  installation instructions
  [here](https://github.com/gabime/spdlog/wiki/9.-CMake).

## Building and Installing the Wallaroo C++ Library

In order to use the Wallaroo C++ API you must install the Wallaroo C++ API header files and library. At the terminal, go to the `wallaroo` repository directory and run the following commands:

```bash
cd lib/wallaroo/cpp_api/cpp/cppapi/
mkdir build
cd build
cmake ..
make
sudo make install
```

This will build the C++ library and install the library and associated header files in your system.

### Building a Wallaroo C++ Application

Let's start by building one of the example applications that uses the C++ API, `counter-app`. Go to the `book/examples/cpp/counter-app` directory and run these commands:

```bash
mkdir build
```

**On MacOS**:

```bash
clang++ --debug -c -o build/Counter.o cpp/Counter.cpp -Wall -std=c++11 -Ihpp
```

**On Linux**:

```bash
gcc --debug -c -o build/Counter.o cpp/Counter.cpp -Wall -std=c++11 -Ihpp
```

Then on either platform, continue with:

```bash
ar rs build/libcounter.a build/Counter.o
ponyc --debug --export --output=build \
  --path=../../../../lib:../../../../lib/wallaroo/cpp_api/cpp/cppapi/build/build/lib:./build \
  counter-app
```

Let's break down what each of these lines does:

* `mkdir build` -- Create the directory where build artifacts will be placed.
* `clang++` or `gcc` followed by ` --debug -c -o build/Counter.o cpp/Counter.cpp -Wall -std=c++11
  -Ihpp` -- Build the C++ application code.
* `ar rs build/libcounter.a build/Counter.o` -- Create an archive from
  the compiled C++ application code.
* `ponyc ...` -- Build the Wallaroo application. The `--path`
  arguments indicate the location of the Wallaroo Pony library
  (`../../lib`), the location of the Pony C++ API library
  (`../../lib/wallaroo/cpp_api/cpp/cppapi/build/build/lib`), and the
  location of the application library (`./build`). Note that this
  points to the local build of the C++ library; the installed location
  will vary from system to system (for example, in
  `/usr/local/lib/WallarooCppApi/` on Mac OS X).

The project includes a `Makefile` which can be run with the `make` command; it will execute these build steps for you. You can use it as a template for your own project, or you can use another build system of your choice.
