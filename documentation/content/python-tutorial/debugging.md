---
title: "Debugging"
menu:
  docs:
    parent: "pytutorial"
    weight: 80
toc: true
---
As you're developing Python Wallaroo applications, there will come a time where you will need to do some debugging during your development process. Debugging can be as simple as inserting a `print` statement in your code (we even do it in our examples) or a bit more involved by using a debugger to get backtraces and such. In this section we'll cover how to debug using `print`, an interactive debugger, and a remote debugger. It will help if you've gone through the [Python API Introduction](/python-tutorial/), [Setting Up Your Environment for Wallaroo](/python-installation/), and [Writing Your Own Wallaroo Python Application](/python-tutorial/writing-your-own-application/) sections prior to continuing so you're aware of the components that make up a Python Wallaroo application and how they interact with each other.

## Debugging Using `print` and `repr`

The simplest way to do some debugging would be to include a `print` statement in your code to analyze data. 

Using `print` is a very useful way to get logged output that you can return to and analyze after your program has completed running. However, there are some downsides when using `print` to debug: you'll need to add a `print` statement everywhere you predict you might need it, you can't get a "state of the world" look at your application, etc.


Using `print` in Python is not without risks. If you try to print a Unicode string, and your locale does not support Unicode, you may encounter an error like the following:

```python
>>> u = u'\ua000abcd\u07b4'
>>> print(u)
Traceback (most recent call last):
  File "<stdin>", line 1, in <module>
UnicodeEncodeError: 'ascii' codec can't encode character u'\ua000' in position 0: ordinal not in range(128)
```

With a streaming input application, you can't always be certain about the contents of the data you try to print. However, you can effectively avoid this sort of error by printing the [byte representation](https://docs.python.org/2/library/repr.html) of your data instead, using `print repr(data)`. In that case, the same code that resulted in an error before will provide a useful printout of the contents of the data object:

```python
>>> u = u'\ua000abcd\u07b4'
>>> print repr(u)
u'\ua000abcd\u07b4'
```

## Debugging Using PDB

 If you need a more robust tool to do debugging, the Python standard library provides `pdb`. `pdb` is an interactive debugger which gives you the option to set breakpoints, inspect the stack frames, and other features expected from an interactive debugger. A quick example of using `pdb` in your application would be importing the `pdb` module and then calling its `set_trace()` function. The `import pdb` command goes in the module you pass to `--application-module` when running `machida` or `machida3`. Usage example:

```python
import pdb
# ...
def application_setup(arg):
    pdb.set_trace()
        # ...
```

The above will insert a breakpoint in the current stack frame and allow you to inspect the `application_setup` function. `pdb` comes with a nice set of features so if you're interested in using it go have a look at the official [documentation](https://docs.python.org/2/library/pdb.html).

## Other Debugging Options

Debugging using `print` or `pdb` is great because they're available on all platforms. However, we realize you might have your own debugging process. We encourage you to use the tools that best fit your needs and we are available to help get you set up if needed.
