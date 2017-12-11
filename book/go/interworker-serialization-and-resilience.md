# Interworker Serialization and Resilience

Wallaroo applications can scale horizontally by running multiple worker processes (ideally on different machines connected by a fast network). Worker processes send each other encoded objects, some of which may contain Python objects. In order to make this work, the application developer must provide serialization and deserialization functions that convert between objects and `byte` slices that represent those objects. The user then sets the `wallarooapi.Serialization` and `wallarooapi.Deserialization` variables to point to the user-defined serialization and deserialization function respectively.

Wallaroo applications can be made resilient by persisting their state to disk so that if they crash they can recover their state. The resilience system uses the same mechanism that is used for interworker serialization.

## Serialization

Serialization is the process of creating a string of bytes that represents an object that will be sent to another worker. The application developer must provide a function with the signature `func (interface{}) []byte` that takes the object to be serialized as its argument and returns a `byte` slice that represents that object.

## Deserialization

Deserialization is the other side of serialization, taking a string of bytes that represents an object and returning the object. The application developer must provide a function with the signature `func ([]byte) interface{}` that takes the `byte` slice representation of the object and returns the object.

## What Needs to Be Serialized and Deserialized

Your application must handle all of these type of objects in its serialization and deserialization functions:
* partition functions
* decoders
* encoders
* computations
* computation builders
* state computations
* state objects
* messages that pass between steps in a topology
