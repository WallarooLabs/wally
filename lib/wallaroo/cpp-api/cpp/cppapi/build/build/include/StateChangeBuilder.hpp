#ifndef __STATECHANGEBUILDER_H__
#define __STATECHANGEBUILDER_H__

#include "StateChange.hpp"

namespace wallaroo
{
class StateChangeBuilder: public ManagedObject
{
public:
  virtual StateChange *build(uint64_t idx_) = 0;
};
}

#endif // __STATECHANGEBUILDER_H__
