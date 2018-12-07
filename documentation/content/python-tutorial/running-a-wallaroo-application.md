---
title: "Running A Wallaroo Application"
menu:
  docs:
    parent: "pytutorial"
    weight: 1
toc: true
---
## Setting Up Wallaroo

You should have already completed the [setup instructions](({< ref "choosing-an-installation-option.md" >}}) in the "Python Installation" guide.

## Running the Application

Wallaroo uses an embedded Python runtime wrapped with a C API around it that lets Wallaroo execute Python code and read Python variables. So when `machida --application-module my_application` is run, `machida` (the binary we previously compiled), loads up the `my_application.py` module inside of its embedded Python runtime and executes its `application_setup()` function to retrieve the application topology it needs to construct in order to run the application. `machida3` does the same, but with an embedded Python 3 runtime instead of Python 2.7.

Generally, in order to build a Wallaroo Python application, the following steps should be followed:

* Build the `machida` or `machida3` binary (this only needs to be done once)
* `import wallaroo` in the Python application's `.py` file
* Create classes that provide the correct Wallaroo Python interfaces (more on this later)
* Define an `application_setup` function that uses the `ApplicationBuilder` from the `wallaroo` module to construct the application topology.
* Run `machida` or `machida3` with the application module as the `--application-module` argument

Once loaded, Wallaroo executes `application_setup()`, constructs the appropriate topology, and enters a `ready` state where it awaits incoming data to process.

### A Note About PYTHONPATH

Machida uses the `PYTHONPATH` environment variable to find modules that are imported by the application. You will have at least two modules in your `PYTHONPATH`: the application module and the `wallaroo` module. If you have installed Wallaroo as instructed and follow the [Starting a new shell for Wallaroo](/book/getting-started/starting-a-new-shell.md) instructions each time you start a new shell, the `walalroo` module and any application modules in your current directory will be automatically added to the `PYTHONPATH`.

If the Python module you want is in a different directory than your current, like: `$HOME/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/examples/python/alerts_stateless/alerts.py`, in order to use the module you would export the `PYTHONPATH` like this:

```bash
export PYTHONPATH="$HOME/wallaroo-tutorial/wallaroo-{{% wallaroo-version %}}/examples/python/alerts_stateless:$PYTHONPATH"
```

## Next Steps

To try running an example, go to [the Alerts example application](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/alerts_stateless/) and follow its [instructions](https://github.com/WallarooLabs/wallaroo/tree/{{% wallaroo-version %}}/examples/python/alerts_stateless/README.md).

To learn how to write your own Wallaroo Python application, continue to [Writing Your Own Application](writing-your-own-application.md)

To find out more detail on the command line arguments and other aspects of running Wallaroo application, see the [Running Wallaroo](/book/running-wallaroo/running-wallaroo.md) section.
