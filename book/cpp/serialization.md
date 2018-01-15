# C++ Serialization

Wallaroo makes it possible to distribute computations across multiple workers. In order to do this, objects must be serialized and deserialized at various points. Wallaroo controls when objects are serialized and deserialized, but the programmer is left with a great deal of control over how this is done.

## Classes That Support Serialization

* data passed as messages between steps (`wallaroo::Data`)
* state computations (`wallaroo::StateComputation`)
* sink encoders (`wallaroo::SinkEncoder`)
* keys (`wallaroo::Key`)
* state change builders (`wallaroo::StateChangeBuilder`)

## Object Serialization

When Wallaroo needs to serialize an object, it follows this procedure:

1. call the `size_t serialize_get_size()` method on the object to find out how many bytes are required to serialize the object
2. allocate a byte buffer of the required size
3. call the `void serialize(char *bytes_)` method on the object to serialize the object, passing it the byte buffer that it just allocated so that the method can set the bytes to the serialized representation of the object

## Object Deserialization

When Wallaroo needs to deserialize a byte array, it calls the application-developer-defined function `wallaroo::Serializable* w_user_data_deserialize (char* bytes_)` function, passing it the byte array. The function is responsible for interpreting the bytes and returning the appropriate object.

## Considerations

### Object Types

All deserialization is done by the same function, so that function is responsible for determining the type of object represented by the incoming byte array. The most common way of doing this is to encode the object type in the serialized representation; the function can read the bytes that represent the type and then call a function to construct the appropriate type of object.

### Serialized Representation Size

The application developer may decide to use a fixed- or variable-length representation for a given class. If a variable-length representation is used then the application developer is responsible for encoding the number of bytes in the message as part of the message and appropriately reading the length and deserializing those bytes.
