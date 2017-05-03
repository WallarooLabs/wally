# PartitionFunctionU64

This class provides a more efficient way of parititioning data, by
using a 64-bit integer as the partitioning key rather than a `Key`
object.

```c++
class PartitionFunctionU64: public ManagedObject
{
public:
  virtual uint64_t partition(Data *data_) = 0;
};
```

## Methods

### `virtual uint64_t partition(Data *data_)`

This method returns the 64-bit integer to use for partitioning data.
