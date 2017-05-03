# PartitionU64

This class represents a partition where the partition keys are 64-bit
integers rather than `Key` objects.

```c++
class PartitionU64
{
public:
  virtual PartitionFunctionU64 *get_partition_function() = 0;
  virtual size_t *get_number_of_keys() = 0;
  virtual uint64_t get_key(size_t idx_) = 0;
};
```

## Methods

### `virtual PartitionFunctionU64 *get_partition_function()`

This method returns the partition function object.

### `virtual size_t *get_number_of_keys()`

This method returns the number of keys associated with this partition.

### `virtual uint64_t get_key(size_t idx_)`

This method returns the key object associated with the index `idx_`.
