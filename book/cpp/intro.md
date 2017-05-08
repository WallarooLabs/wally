# C++ API Introduction

The Wallaroo C++ API can be used to write Wallaroo applications
entirely in C++. This lets developers quickly get started with
Wallaroo by leveraging their existing C++ knowledge.

In order to write a Wallaroo application in C++, the developer creates
classes that subclass ones that are provided by the API, creates a C
function to handle deserialization, and writes a function that uses an
application builder object to define the layout of the application.

For a basic overview of what Wallaroo does, please read
[What is Wallaroo?](/book/what-is-wallaroo.md) and
[Core Concepts](/book/core-concepts/intro.md). These
documents will help you understand the system at a high level so that
you can see how the pieces of the C++ API fit into it.
