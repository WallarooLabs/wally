#ifndef __PARTITION_FUNCTION_HPP__
#define __PARTITION_FUNCTION_HPP__

#include "ManagedObject.hpp"
#include "Key.hpp"

namespace wallaroo
{
class PartitionFunction: public ManagedObject
{
public:
  virtual Key *partition(Data *data_) = 0;
};

class PartitionFunctionU64: public ManagedObject
{
public:
  virtual uint64_t partition(Data *data_) = 0;
};
}

#endif // __PARTITION_FUNCTION_HPP__
