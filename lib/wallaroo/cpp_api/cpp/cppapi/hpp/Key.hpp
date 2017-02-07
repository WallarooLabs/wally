#ifndef __KEY_HPP__
#define __KEY_HPP__

#include "ManagedObject.hpp"
#include <cstdint>

namespace wallaroo
{
class Key: public ManagedObject
{
public:
  virtual uint64_t hash() = 0;
  virtual bool eq(Key *other_) = 0;
};
}

#endif // __KEY_HPP__
