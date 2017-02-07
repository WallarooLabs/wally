#ifndef __MANAGED_OBJECT_HPP__
#define __MANAGED_OBJECT_HPP__

#include <cstdint>
#include "Serializable.hpp"

namespace wallaroo
{
class ManagedObject: public Serializable
{
public:
  virtual ~ManagedObject();
};
}

#endif // __MANAGED_OBJECT_HPP__
