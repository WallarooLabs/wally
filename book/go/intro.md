# Go API Introduction

The Wallaroo Go API can be used to write Wallaroo applications using Go on 64-bit platforms.

In order to write a Wallaroo application in Go, the developer creates a series of functions and types that provide methods expected by Wallaroo (see [Wallaroo Go API Classes](api/api.md) for more detail). Additionally, the developer writes an entry point function that Wallaroo uses to lay out the application.

For a basic overview of what Wallaroo does, read [What is Wallaroo](/book/what-is-wallaroo.md) and [Core Concepts](/book/core-concepts/intro.md). These documents will help you understand the system at a high level so that you can see how the pieces of the Go API fit into it.

## The Basics

A Wallaroo Go application is a combination of Go library (technically Cgo, we'll cover that in more detail later) and Wallaroo framework code provided by Wallaroo Labs.

You, the application developer, write your application in Go and then compile it into a Go library that will be linked into a final executable file using the Pony compiler.

## Next Steps

To set up your environment for writing and running Wallaroo Go applications, refer to [our installation instructions](getting-started/setup.md).
