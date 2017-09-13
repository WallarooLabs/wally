# Debugging Python Wallaroo Applications

As you're developing Python Wallaroo applications, there will come a time where you will need to do some debugging during your development process. Debugging can be as simple as inserting a `print` statement in your code (we even do it in our examples) or a bit more involved by using a debugger to get backtraces and such. In this section we'll cover how to debug using `print`, an interactive debugger, and a remote debugger. It will help if you've gone through the [Python API Introduction](book/python/intro.md), [Building A Wallaroo Python Application](book/python/building.md), and [Writing Your Own Wallaroo Python Application](book/python/writing-your-own-application.md) sections prior to continuing so you're aware of the components that make up a Python Wallaroo application and how they interact with each other.

## Debugging Using `print`

The simplest way to do some debugging would be tossing a `print` statement in your code to analyze data. You can see several examples of this in our reverse [example](https://github.com/WallarooLabs/wallaroo/tree/release-0.1.0-rc2/examples/python/reverse/reverse.py) where we have `print` statements in our `Encoder`, `Decoder`, and `Reverse` classes. Here's an example in our `compute` function in our `Reverse` class:

```bash
def compute(self, data):
    print "compute", data
    return data[::-1]
```

In this example, we'll be printing the incoming data before we reverse it.


Using `print` is a very useful way to get logged output that you can return to and analyze after your program has completed running. However, there are some downsides when using `print` to debug; you'll need to toss a `print` statement everywhere you predict you might need it, you can't get a "state of the world" look at your application, etc.

## Debugging Using PDB

 If you need a more robust tool to do debugging, the Python standard library provides `pdb`. `pdb` is an interactive debugger which gives you the option to set breakpoints, inspect the stack frames, and other features expected from an interactive debugger. A quick example of using `pdb` in your application would be importing the `pdb` module and then calling its `set_trace()` function. The `import pdb` command goes in the module you pass to `--application-module` when running `machida`. Usage example:

```
import pdb
# ...
def application_setup(arg):
    pdb.set_trace()
        # ...
```

The above will insert a breakpoint in the current stack frame and allow you to inspect the `application_setup` function. `pdb` comes with a nice set of features so if you're interested in using it go have a look at the official [documentation](https://docs.python.org/2/library/pdb.html).

For Windows users who would prefer to do remote debugging due to Bash/WSL, continue to our [Setting up Windows for Remote Debugging using Wing IDE](/book/python/wing-on-windows-remote-debugging-setup.md) instructions.


## Other Debugging Options

Debugging using `print` or `pdb` is great because they're available on all platforms. However, we realize you might have your own debugging process. We encourage you to use the tools that best fit your needs and we are available to help get you set up if needed.

We've had a user base reach out to us to help them get set up in using [Wing IDE](https://wingware.com/) to do remote debugging. Wing is available on all platforms and includes its own powerful debugger that allows for interactive debugging via the IDE. Because of the unique nature of developing Wallaroo on Windows (all programs are run in Linux via Bash/WSL) we've included a section for [Setting up Windows for Remote Debugging using Wing IDE](book/python/wing-on-windows-remote-debugging-setup.md) and [Setting up Wing IDE for Remote Debugging a Python Wallaroo Application](book/python/wing-remote-debugging.md).
