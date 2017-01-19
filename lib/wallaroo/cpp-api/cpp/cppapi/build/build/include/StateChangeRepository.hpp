#ifndef __STATECHANGEREPOSITORY_H__
#define __STATECHANGEREPOSITORY_H__

#include "ManagedObject.hpp"
#include "StateChange.hpp"

namespace wallaroo
{
class StateChangeRepository: public ManagedObject
{
public:
  virtual StateChange *operator[] (const uint64_t index_) = 0;
  virtual StateChange *lookup_by_name(const char *name_) = 0;
};
}

#endif // __STATECHANGEREPOSITORY_H__
