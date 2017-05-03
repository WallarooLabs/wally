# Key

A key is used to partition messages between workers. A partition
function is applied to each message and a key is returned which is
then used ot route the message to the correct worker.

*Note:* If possible, it is more efficient to use
`PartitionFunctionU64`, which returns a 64-bit number as a key.

```c++
class Key: public ManagedObject
{
public:
  virtual uint64_t hash() = 0;
  virtual bool eq(Key *other_) = 0;
};
```

## Methods

### `virtual uint64_t hash()`

This method returns a 64-bit integer that is used for paritioning. It
is not the actual partition key, but it is used during key lookup.

### `virtual bool eq(Key *other_)`

This method returns true if this key is equal to `other_` in some way
defined by the application developer.
