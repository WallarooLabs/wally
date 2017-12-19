# Go API Introduction

The Wallaroo Go API can be used to write Wallaroo applications using Go. 

In order to write a Wallaroo application in Go, the developer creates a series fo functions and types that provide methods expected by Wallaroo (see [Wallaroo Go API Classes](api.md) for more detail on this). Additionally, the developer writes an entry point function that Wallaroo uses to layout the application. 

For a basic overview of what Wallaroo does, read [What is Wallaroo](/book/what-is-wallaroo.md) and [Core Concepts](/book/core-concepts/intro.md). These documents will help you understand the system at a high level so that you can see how the pieces of the Go API fit into it.

## The Basics

A Wallaroo Go application is a combination of Go library (techinically Cgo, we'll cover that in more detail later) and Wallaroo framework code provided by Wallaroo Labs.

You, the application developer, write your application in Go and then compile it into a Go library that will be linked into a final binary using the Pony compiler.

The Wallaroo Go API has received testing on OSX El Capitan, MacOS High Sierra, and Ubuntu Xenial.

## Setting up your environment

The Wallaroo Go API is currently bleeding-edge. You'll need to install a number of dependencies that you'll need to:

* Run the example applications that are used to teach you the API
* Start developing your own applications

### Install Go

You'll need a Go 1.9.x compiler. You can get one from the [Go website](https://golang.org/dl/).

### Install the Pony compiler

You'll need to install the Pony compiler from source. You can find the Pony compiler and instructions on how to install from source on [GitHub](https://github.com/ponylang/ponyc).

When building form source. Make sure you are using a known "good commit". IE one that Wallaroo Labs has tested with:

```bash
git checkout 314db6ae1a8960a1eab3c5a20f74e3ce4c67f222
```

## Install the Pony dependency manager 'stable'

Installation instructions for Linux and MacOS are available on the [Pony stable GitHub repo](https://github.com/ponylang/pony-stable).

### Build Wallaroo support utilities

The various examples you will be asked to run as part of our teaching examples.
You can build them by running the following make command from the root of the Walaroo repository: 

```bash
make build-giles-all build-utils-cluster_shutdown-all
```

### Installing the Wallaroo metrics UI

Installing the metrics UI is an optional step. It's not used as part of running any of the teaching examples. To install the UI on Linux, please follow the directions [here](https://docs.wallaroolabs.com/book/getting-started/linux-setup.html#install-docker). Or if you are on MacOS, follow [these directions](https://docs.wallaroolabs.com/book/getting-started/macos-setup.html#install-docker).

## Next Steps

To learn how to write your own application, refer to [Writing Your Own Application](writing-your-own-application.md).

To read about the structure and requirements of each API class, refer to [Wallaroo Go API Classes](api.md).

To read about the command-line arguments Wallaroo takes, refer to [Appendix: Wallaroo Command-Line Options](/book/appendix/wallaroo-command-line-options.md).

To browse complete examples, go to [Wallaroo Go Examples](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go).
