# Computation

A computation receives message data from an earlier computation or
source and either returns new message data or returns null, indicating
that the incoming message should be filtered.

```c++
class Computation: public ManagedObject
{
public:
  virtual const char *name() = 0;
  virtual Data *compute(Data *input_) = 0;
};
```

## Methods

### `virtual const char *name()`

This method returns the name of the computation. This name is used for
logging and reporting.

### `virtual Data *compute(Data *input_)`

This method accepts a message data object. It is reponsible for
casting the incoming message data to the appropriate type, handling
the message data, and returning either a new message data object or
`NULL`.
