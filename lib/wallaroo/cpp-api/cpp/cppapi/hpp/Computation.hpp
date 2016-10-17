#ifndef __COMPUTATION_H__
#define __COMPUTATION_H__

#include "ManagedObject.hpp"
#include "Data.hpp"
#include "State.hpp"

namespace wallaroo {
class Computation: public ManagedObject {
public:
  virtual char *name() = 0;
  virtual Data *compute(Data *input_) = 0;
};

class StateComputation: public ManagedObject {
public:
  virtual char *name() = 0;
  virtual Data *compute(Data *input_, State *state_) = 0;
};
}

#endif // __COMPUTATION_H__
