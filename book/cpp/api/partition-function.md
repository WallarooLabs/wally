# PartitionFunction

A parition function is applied to message data to get a key, which is
then used to route the message to the appropriate worker.

```c++
class PartitionFunction: public ManagedObject
{
public:
  virtual Key *partition(Data *data_) = 0;
};
```

## Methods

### `virtual Key *partition(Data *data_)`

This method takes the message data and returns the key to use for
routing it to the appropriate worker.
