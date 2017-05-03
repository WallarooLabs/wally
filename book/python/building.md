# Building A Wallaroo Python Application

## Setting Up Wallaroo

You should have already completed the [setup instructions](/getting-started/setup.md) in the "getting started" section of this guide.

### Requirements

* git
* clang >=3.5
* python development libraries
* Sendence Pony compiler
* Wallaroo Python API
* Giles Sender

### clang

* on Ubuntu Trusty
  ```bash
  sudo apt-get install clang-3.5
  sudo ln -s /usr/bin/clang-3.5 /usr/bin/clang
  ```

* on Ubuntu Xenial
  ```bash
  sudo apt-get install clang
  ```

### Python-dev

```bash
sudo apt-get install python-dev
```

### Wallaroo

If you don't already have it installed, clone the Wallaroo clone the Wallaroo repository. The remaining directions assume you have cloned Wallaroo into your home directory.

```bash
cd ~/
git clone https://github.com/sendence/wallaroo.git
cd wallaroo/horse-snake/dianoga
```

Create the `build` directory if it doesn't already exist.

```bash
mkdir build
```

Build the `dianoga`

```bash
clang -g -o build/python-wallaroo.o -c cpp/python-wallaroo.c
ar rvs build/libpython-wallaroo.a build/python-wallaroo.o
ponyc --debug --output=build --path=build --path=../../lib/ .
```

Once built, the `./build/dianoga` binary will work with any `.py` file, so it is not necessary to repeat this step for every new application built with the Wallaroo Python API.

### Giles sender

Build the sender we will be using to send framed data to Wallaroo.

```bash
cd ~/wallaroo/giles/sender
stable fetch && stable env ponyc
```

## Running a Wallaroo Python Application

### A Note on How Wallaroo Handles a Python Application

Wallaroo uses an embedded Python runtime wrapped with a C API around it that lets Wallaroo execute Python code and read Python variables. So when `./build/dianoga --wallaroo-module my_application` is run, `dianoga` (the binary we previously compiled), loads up the `my_application.py` module inside of its embedded Python runtime and executes its `application_setup()` function to retrieve the application topology it needs to construct in order to run the application.

Generally, in order to build a Wallaroo Python application, the following steps should be followed:

* Build the dianoga binary (this only needs to be done once)
* `import wallaroo` in the python application's `.py` file
* Create classes that provide the correct Wallaroo Python interfaces (more on this later)
* Define an `application_setup` function that uses the `ApplicationBuilder` from the `wallaroo` module to construct the application topology.
* Run `dianoga` with the application file as the `--wallaroo-module` argument

Once loaded, Wallaroo executes `application_setup()`, constructs the appropriate topology, and enters a `ready` state where it awaits incoming data to process.

### Running a Simple Stateless Application

Let's start by running one of the example applications that uses the Python API, `reverse_word`: a simple stateless computation that reverses words.

Go to the `horse-snake/dianoga` directory.

Export the current directory as `PYTHONPATH`.

```bash
export PYTHONPATH=.
```

Set up a listener.

```bash
nc -l 127.0.0.1 7002
```

Run `dianoga` with `--wallaroo-module reverse_word`.

```bash
build/dianoga -i 127.0.0.1:7010 -o 127.0.0.1:7002 -m 127.0.0.1:8000 -c 127.0.0.1:6000 -d 127.0.0.1:6001 -n worker-name --ponythreads=1 --wallaroo-module reverse_word
```

Send some messages

```bash
../../giles/sender/sender --buffy 127.0.0.1:7010 --file ./words.txt --batch-size 5 --interval 100_000_000 --messages 150 --repeat --ponythreads=1
```

Observe the reversed values in the output!

To learn how to write your own Wallaroo Python application, continue to [Writing Your Own Application](writing-your-own-application.md)
