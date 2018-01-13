# Running A Wallaroo Python Application

## Setting Up Wallaroo

You should have already completed the [setup instructions](/book/getting-started/setup.md) in the "Setting Up Your Environment for Wallaroo" section of this guide.

## Running the Application

Wallaroo uses an embedded Python runtime wrapped with a C API around it that lets Wallaroo execute Python code and read Python variables. So when `machida --application-module my_application` is run, `machida` (the binary we previously compiled), loads up the `my_application.py` module inside of its embedded Python runtime and executes its `application_setup()` function to retrieve the application topology it needs to construct in order to run the application.

Generally, in order to build a Wallaroo Python application, the following steps should be followed:

* Build the machida binary (this only needs to be done once)
* `import wallaroo` in the Python application's `.py` file
* Create classes that provide the correct Wallaroo Python interfaces (more on this later)
* Define an `application_setup` function that uses the `ApplicationBuilder` from the `wallaroo` module to construct the application topology.
* Run `machida` with the application module as the `--application-module` argument

Once loaded, Wallaroo executes `application_setup()`, constructs the appropriate topology, and enters a `ready` state where it awaits incoming data to process.

### A Note About PYTHONPATH

Machida uses the `PYTHONPATH` environment variable to find modules that are imported by the application. You will have at least two modules in your `PYTHONPATH`: the application module and the `wallaroo` module. For example, if you have followed the directions for setting up the tutorial then the Wallaroo Python module is in `$HOME/wallaroo-tutorial/machida/wallaroo.py` and the "Celsius to Fahrenheit" application module is in `$HOME/wallaroo-tutorial/examples/python/celsius/celsius.py`, so you would export `PYTHONPATH` like this:

```bash
export PYTHONPATH="$PYTHONPATH:$HOME/wallaroo-tutorial/machida:$HOME/wallaroo-tutorial/examples/python/celsius"
```

If you are working your way through the tutorial you might find it easier to set up `PYTHONPATH` to use whatever directory you are in as the search path so that you can run the application that is the current directory. To do this, you would export `PYTHONPATH` like this:

```bash
export PYTHONPATH="$PYTHONPATH:$HOME/wallaroo-tutorial/machida:."
```

If you chose to do this while working through the tutorial, you might also find it useful to add the path to the `machida` executable to your `PATH`, which can be done like this:

```bash
export PATH="$PATH:$HOME/wallaroo-tutorial/machida/build"
```

## Next Steps

To try running an example, go to [the Reverse example application](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/reverse/) and follow its [instructions](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python/reverse/README.md).

To learn how to write your own Wallaroo Python application, continue to [Writing Your Own Application](writing-your-own-application.md)

To find out more detail on the command line arguments and other aspects of running Wallaroo application, see the [Running Wallaroo](/book/running-wallaroo/running-wallaroo.md) section.
