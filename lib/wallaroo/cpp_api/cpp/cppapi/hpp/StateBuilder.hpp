#ifndef __STATEBUILDER_HPP__
#define __STATEBUILDER_HPP__

#include "State.hpp"

namespace wallaroo
{
  class StateBuilder: public ManagedObject
  {
  public:
    virtual const char *name() = 0;
    virtual State *build() = 0;
  };
}

#endif // __STATEBUILDER_HPP__
