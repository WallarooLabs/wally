# Interworker Serialization and Resilience

Wallaroo applications can scale horizontally by running multiple worker processes (ideally on different machines connected by a fast network). Worker processes send each other encoded objects, some of which may contain Python objects. In order to make this work, the application developer must provide functions called `serialize` and `deserialize` that convert between objects and strings that represent those objects.

Wallaroo applications can be made resilient by persisting their state to disk so that if they crash they can recover their state. The resilience system uses the same mechanism that is used for interworker serialization.

## Serialization

Serialization is the process of creating a string of bytes that represents an object that will be sent to another worker. The application developer must provide a function called `serialize(obj)` that takes the object to be serialized as its argument and returns a string that represents that object.

Python's built-in `pickle` module can take an object and return a string representation of it. If `pickle` is sufficient for your needs then the `serialize` function can be implemented as:

```python
def serialize(obj):
    return pickle.dumps(obj)
```

## Deserialization

Deserialization is the other side of serialization, taking a string of bytes that represents an object and returning the object. The application developer must provide a function called `deserialize(s)` that takes the string representation of the object and returns the object. If the object was serialized with the `pickle` module as in the example above then the `deserialize` method can be implemented as:

```python
def deserialize(s):
    return pickle.loads(s)
```
