---
title: "Python API Introduction"
menu:
  docs:
    parent: "pytutorial"
    weight: 1
toc: true
layout: single
---
The Wallaroo Python API can be used to write Wallaroo applications entirely in Python without needing Java or a JVM. This lets developers quickly get started with Wallaroo by leveraging their existing Python knowledge. There are two different version of Machida, one for Python 2.7 on 64-bit platforms called `machida` and one for Python 3.5+ on 64-bit platforms called `machida3`. If you are using Python 3.5+ then you should substitute `machida3` for `machida` as you follow the instructions in the documentation.

In order to write a Wallaroo application in Python, the developer creates the functions (decorated with [the Wallaroo API](/python-tutorial/api/)) to be run at each stage of their application, along with an entry point function called `application_setup`.

For a basic overview of what Wallaroo does, read [What is Wallaroo](/) and [Core Concepts](/core-concepts/). These documents will help you understand the system at a high level so that you can see how the pieces of the Python API fit into it.

## Machida

Machida is the program that runs Wallaroo applications written using the Wallaroo Python API. It takes a module name as its `--application-module` argument and requires a method called `application_setup(...)` to be defined in that module. This method returns the structure describing the Wallaroo application in terms of Python objects, which is then used to coordinate calling those objects’ methods with the appropriate arguments as the application is running.

Machida runs Wallaroo Python applications using an embedded CPython interpreter. You should be able to use any Python modules that you would normally use when creating a Python application.

## Python Packages

Wallaroo programs that use the Python API can use any packages that would be used with a normal Python program, including your own packages and third party packages. In order to use them, they must be installed on every machine in the Wallaroo cluster and must be accessible via the `PYTHONPATH`.

We recommend using [virtualenv](https://virtualenv.pypa.io/en/stable/) with Wallaroo. See [Wallaroo and Virtualenv](/python-tutorial/virtualenv/) for set up and usage instructions.

## Next Steps

If you haven't already done so, set up your environment for writing and running Wallaroo Python application, refer to [our installation instructions](/python-installation/). Otherwise, [onwards into the tutorial](/python-tutorial/running-a-wallaroo-application/).
