#ifndef __PARTITION_HPP__
#define __PARTITION_HPP__

#include "PartitionFunction.hpp"
#include "Key.hpp"

namespace wallaroo {
  class Partition
  {
  public:
    virtual PartitionFunction *get_partition_function() = 0;
    virtual size_t get_number_of_keys() = 0;
    virtual Key *get_key(size_t idx_) = 0;
  };

  class PartitionU64
  {
  public:
    virtual PartitionFunctionU64 *get_partition_function() = 0;
    virtual size_t get_number_of_keys() = 0;
    virtual uint64_t get_key(size_t idx_) = 0;
  };
}


#endif // __PARTITION_HPP__
