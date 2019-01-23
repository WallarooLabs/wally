---
title: "Working with State"
menu:
  toc:
    parent: "core-concepts"
    weight: 3
toc: true
---
Wallaroo's state objects allow developers to define their own domain-specific data structures that Wallaroo manages. These state objects are used to store state in running application. They provide safe, serialized access to data in a highly parallelized environment. In "Working in State", we are going to take you through how you can operate on your state objects.

## State computations

Imagine a word counting application. We'll have a state object for each different word. We might represent the state for each word's total like this:

```python
class WordTotal(object):
    count = 0
```

State computations allow you to read and write data to state objects. State computations have 2 inputs and 1 output. 

* State computation input:
  - The message to be processed
  - The state object we are operating on
* State computation output:
  - An optional output message

## Thread Safety

When a state computation is running, one of the parameters it is provided is the state to operate on. That state will only be provided to a single state computation at a time. Within the state computation, you don't have to worry about thread synchronization issues. 
