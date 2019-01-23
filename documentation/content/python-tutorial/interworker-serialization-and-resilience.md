---
title: "Inter-worker Serialization and Resilience"
menu:
  toc:
    parent: "pytutorial"
    weight: 50
toc: true
---
Wallaroo applications can scale horizontally by running multiple worker processes (ideally on different machines connected by a fast network). Worker processes send each other encoded objects, some of which may contain Python objects. Wallaroo provides serialization and deserialization based on the `pickle` module; if this is sufficient for your needs then you don't need to write any serialization or deserialization code. If `pickle` is insufficient for your application (for example, if `pickle` is too slow or if you are using classes that cannot be serialized or deserialized with `pickle`) then you must provide your own `serialize` and `deserialize` functions that convert between objects and strings that represent those objects. If you provide your own `serialize` and `deserialize` functions then they must be in the top level module of your application.

Wallaroo applications can be made resilient by persisting their state to disk so that if they crash they can recover their state. The resilience system uses the same mechanism that is used for inter-worker serialization.

## Serialization

Serialization is the process of creating a string of bytes that represents an object that will be sent to another worker. The application developer must provide a function called `serialize(obj)` that takes the object to be serialized as its argument and returns a string that represents that object.

Python's built-in `pickle` module can take an object and return a string representation of it. If `pickle` is sufficient for your needs then the `serialize` function can be implemented as:

```python
def serialize(obj):
    return pickle.dumps(obj)
```

As mentioned above, providing a `serialize` function is optional; Wallaroo provides a default `serialize` function that uses `pickle` and that may be fine for your application.

## Deserialization

Deserialization is the other side of serialization, taking a string of bytes that represents an object and returning the object. The application developer must provide a function called `deserialize(s)` that takes the string representation of the object and returns the object. If the object was serialized with the `pickle` module as in the example above then the `deserialize` method can be implemented as:

```python
def deserialize(s):
    return pickle.loads(s)
```

As mentioned above, providing a `deserialize` function is optional; Wallaroo provides a default `deserialize` function that uses `pickle` and that may be fine for your application.

## A Note About Serializable Objects

There are a number of Python packages that can serialize and deserialize Python objects. You can also design and implement your own serialization protocol if you feel that you have specific needs that are not met by existing systems. Whatever you do, you must make sure that all of your objects can be serialized and deserialized with the system that you are using. For example, if your application sends message data that contains objects created by third party libraries, you should make sure that those objects can be serialized. Some Python packages provide wrappers around C data, which cannot be serialized using `pickle`, so if you need to send this type of data then you will have to provide another way to serialize it.
