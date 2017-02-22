#ifndef __COMPUTATIONBUILDER_HPP__
#define __COMPUTATIONBUILDER_HPP__

#include "Computation.hpp"

namespace wallaroo
{
  class ComputationBuilder
  {
  public:
    virtual Computation *build() = 0;
  };
}

#endif
