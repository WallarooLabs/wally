# Go API Introduction

The Wallaroo Go API can be used to write Wallaroo applications using Go. 

In order to write a Wallaroo application in Go, the developer creates a series of functions and types that provide methods expected by Wallaroo (see [Wallaroo Go API Classes](api.md) for more detail on this). Additionally, the developer writes an entry point function that Wallaroo uses to lay out the application. 

For a basic overview of what Wallaroo does, read [What is Wallaroo](/book/what-is-wallaroo.md) and [Core Concepts](/book/core-concepts/intro.md). These documents will help you understand the system at a high level so that you can see how the pieces of the Go API fit into it.

## The Basics

A Wallaroo Go application is a combination of Go library (technically Cgo, we'll cover that in more detail later) and Wallaroo framework code provided by Wallaroo Labs.

You, the application developer, write your application in Go and then compile it into a Go library that will be linked into a final binary using the Pony compiler.

## Next Steps

To learn how to write your own application, refer to [Writing Your Own Application](writing-your-own-application.md).

To read about the structure and requirements of each API class, refer to [Wallaroo Go API Classes](api.md).

To read about the command-line arguments Wallaroo takes, refer to [Wallaroo Command-Line Options](/book/running-wallaroo/wallaroo-command-line-options.md).

To browse complete examples, go to [Wallaroo Go Examples](https://github.com/WallarooLabs/wallaroo/tree/{{ book.wallaroo_version }}/examples/go).
