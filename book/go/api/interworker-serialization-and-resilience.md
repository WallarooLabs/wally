# Interworker Serialization and Resilience

Wallaroo applications can scale horizontally by running multiple worker processes (ideally on different machines connected by a fast network). Worker processes send each other encoded objects, some of which may contain Go objects. In order to make this work, the application developer must provide serialization and deserialization functions that convert between objects and `byte` slices that represent those objects. The user then sets the `wallarooapi.Serialization` and `wallarooapi.Deserialization` variables to point to the user-defined serialization and deserialization function respectively.

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

### An Example Serializing Function

As an example of serialization, let's look at the Reverse
application. It converts a `byte` slice into a string, reverses
that string, and sends the reversed string to the encoder, which turns
it into a `byte` slice. The serialization function looks like this:

```go
func Serialize(c interface{}) []byte {
  switch t := c.(type) {
  case *string:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, stringType)
    var b bytes.Buffer
    enc := gob.NewEncoder(&b)
    enc.Encode(c)
    return append(buff, b.Bytes()...)
  case *Reverse:
     buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, reverseType)
    return buff
  case *ReverseBuilder:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, reverseBuilderType)
    return buff
  case *Decoder:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, decoderType)
    return buff
  case *Encoder:
    buff := make([]byte, 4)
    binary.BigEndian.PutUint32(buff, encoderType)
    return buff
  default:
    fmt.Println("SERIALIZE MISSED A CASE")
    fmt.Println(reflect.TypeOf(t))
  }

  return nil
}
```

The switch statement handles all of the types that need to be serialized.  (Remember, the Reverse application does not use stateful computations.  Cases for partition functions, state computations, and state objects do not appear in this example).

* decoders -- the `Decoder` class
* encoders -- the `Encoder` class
* computations -- the `Reverse` class
* computation builders -- the `ReverseBuilder` class
* messages that pass between steps in a topology -- the `string` class

You are free to select any encoding mechanism that you would like. In
this example we have used a 32-bit integer to represent the type of
the encoded class. If the class has any data associated with it, like
the `string` class, you will need to encode that data as well. Go
provides the `gob` module which can encode and decode objects for you;
we recommend you use this unless you have a specific need that it does
not satisfy.

### An Example Deserializing Function

The decoder function performs the opposite operation, taking an
serialized representation and converting it into the object that is
represented. The Reverse application's deserialization function looks
like this:

```go
func Deserialize(buff []byte) interface{} {
  componentType := binary.BigEndian.Uint32(buff[:4])
  payload := buff[4:]

  switch componentType {
  case stringType:
    b := bytes.NewBuffer(payload)
    dec := gob.NewDecoder(b)
    var s string
    dec.Decode(&s)
    return &s
  case reverseType:
    return &Reverse{}
  case reverseBuilderType:
    return &ReverseBuilder{}
  case decoderType:
    return &Decoder{}
  case encoderType:
    return &Encoder{}
  default:
    fmt.Println("DESERIALIZE MISSED A CASE")
  }

  return nil
}

func main() {
}
```

The deserialization function in this example gets the first four bytes
and uses that to determine the type of the object. It then creates the
the appropriate object and fills it with any data that it needs.
