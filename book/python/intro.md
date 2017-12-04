# Python API Introduction

The Wallaroo Python API can be used to write Wallaroo applications entirely in Python without needing Java or a JVM. This lets developers quickly get started with Wallaroo by leveraging their existing Python knowledge. It currently supports Python 2.7. Support for Python 3.X is in the works and we encourage you to contact us if that is a requirement.

In order to write a Wallaroo application in Python, the developer creates classes that provide the methods expected by the API (see [Wallaroo Python API Classes](api.md) for more detail on this) and writes an entry point function that uses the Wallaroo `ApplicationBuilder` to define the layout of their application.

For a basic overview of what Wallaroo does, read [What is Wallaroo](/book/what-is-wallaroo.md) and [Core Concepts](/book/core-concepts/intro.md). These documents will help you understand the system at a high level so that you can see how the pieces of the Python API fit into it.

## Machida

Machida is the program that runs Wallaroo applications written using the Wallaroo Python API. It takes a module name as its `--application-module` argument and requires a method called `application_setup(...)` to be defined in that module. This method returns the structure describing the Wallaroo application in terms of Python objects, which is then used to coordinate calling those objects’ methods with the appropriate arguments as the application is running.

Machida runs Wallaroo Python applications using an embedded CPython interpreter. You should be able to use any Python modules that you would normally use when creating a Python application.

## Python Packages

Wallaroo programs that use the Python API can use any packages that would be used with a normal Python program, including your own packages and third party packages. In order to use them, they must be installed on every machine in the Wallaroo cluster and must be accessible via the `PYTHONPATH`.

We recommend using [virtualenv](https://virtualenv.pypa.io/en/stable/) with Wallaroo. See [Wallaroo and Virtualenv](/book/appendix/virtualenv.md) for set up and usage instructions.

## Next Steps

To set up your environment for writing and running Wallaroo Python application, refer to [Running a Wallaroo Python Application](running-a-wallaroo-python-application.md).

To learn how to write your own application, refer to [Writing Your Own Application](writing-your-own-application.md).

To read about the structure and requirements of each API class, refer to [Wallaroo Python API Classes](api.md).

To read about the command-line arguments Wallaroo takes, refer to [Appendix: Wallaroo Command-Line Options](/book/appendix/wallaroo-command-line-options.md).

To browse complete examples, go to [Wallaroo Python Examples](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/python).
