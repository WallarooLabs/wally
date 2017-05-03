# Partition

A partition stores a partition function and information about the keys
associated with the partition.

```c++
class Partition
{
public:
  virtual PartitionFunction *get_partition_function() = 0;
  virtual size_t *get_number_of_keys() = 0;
  virtual Key *get_key(size_t idx_) = 0;
};
```

## Methods

### `virtual PartitionFunction *get_partition_function()`

This method returns the partition function object.

### `virtual size_t *get_number_of_keys()`

This method returns the number of keys associated with this partition.

### `virtual Key *get_key(size_t idx_)`

This method returns the key object associated with the index `idx_`.
