# Building A Wallaroo Python Application

## Setting Up Wallaroo

You should have already completed the [setup instructions](/book/getting-started/setup.md) in the "getting started" section of this guide.

### Requirements

* git
* clang >=3.5 (on MacOS) or gcc >=5 (on Linux)
* python development libraries
* Sendence Pony compiler
* Wallaroo Python API
* Giles Sender

#### clang (MacOS)

* You should already have `clang` as part of `XCode`. No further steps are needed.

#### gcc (Linux)

* You should already have `gcc` after completing the [Wallaro Linux Setup](/book/getting-started/linux-setup.md).

#### Python-dev

* On MacOS: if you installed Python with Homebrew, you should already have the python development headers. No further steps are needed.

* On Ubuntu:

  ```bash
  sudo apt-get install -y python-dev
  ```

#### Giles sender

Build the sender we will be using to send framed data to Wallaroo.

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/sender
stable env ponyc
```

#### Wallaroo-Python

In order to build `machida` the Wallaroo Python runner, navigate to the `machida` directory in your `wallaroo` repository and execute `make build`.

```bash
cd ~/wallaroo-tutorial/wallaroo/machida
make build
```

Once built, the `machida` binary will work with any `.py` file, so it is not necessary to repeat this step for every new application built with the Wallaroo Python API.

## Running a Wallaroo Python Application

### A Note on How Wallaroo Handles a Python Application

Wallaroo uses an embedded Python runtime wrapped with a C API around it that lets Wallaroo execute Python code and read Python variables. So when `machida --application-module my_application` is run, `machida` (the binary we previously compiled), loads up the `my_application.py` module inside of its embedded Python runtime and executes its `application_setup()` function to retrieve the application topology it needs to construct in order to run the application.

Generally, in order to build a Wallaroo Python application, the following steps should be followed:

* Build the machida binary (this only needs to be done once)
* `import wallaroo` in the python application's `.py` file
* Create classes that provide the correct Wallaroo Python interfaces (more on this later)
* Define an `application_setup` function that uses the `ApplicationBuilder` from the `wallaroo` module to construct the application topology.
* Run `machida` with the application file as the `--application-module` argument

Once loaded, Wallaroo executes `application_setup()`, constructs the appropriate topology, and enters a `ready` state where it awaits incoming data to process.

### A Note on PATH and PYTHONPATH

Since the Python runtime is embedded, finding paths to modules can get complicated. To make our lives easier, we're going to add the location of the `machida` binary to the `PATH` environment variable, and then we're going to add two paths to the `PYTHONPATH` environment variable:

- `.`
- the path of the `machida` directory in the wallaroo repository.

Assuming you installed Machida according to the tutorial instructions you would do:

```bash
export PYTHONPATH="$PYTHONPATH:.:$HOME/wallaroo-tutorial/wallaroo/machida"
export PATH="$PATH:$HOME/wallaroo-tutorial/wallaroo/machida/build"
```

If you would like to skip this step in the future, you add these exports to your `.bashrc` file.

## Next Steps

To try running an example, go to [the Reverse example application](https://github.com/Sendence/wallaroo/tree/master/book/examples/python/reverse/) and follow its [instructions](/book/examples/python/reverse/README.md).

To learn how to write your own Wallaroo Python application, continue to [Writing Your Own Application](writing-your-own-application.md)

To read about the Machida command line arguments, refer to [Appendix: Wallaroo Command-Line Options](/book/appendix/wallaroo-command-line-options.md).
