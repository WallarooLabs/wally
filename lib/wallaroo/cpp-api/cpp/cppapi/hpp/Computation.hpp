#ifndef __COMPUTATION_H__
#define __COMPUTATION_H__

#include "ManagedObject.hpp"
#include "Data.hpp"
#include "State.hpp"
#include "StateChange.hpp"
#include "StateChangeRepository.hpp"
#include "StateChangeBuilder.hpp"

namespace wallaroo {
class Computation: public ManagedObject
{
public:
  virtual const char *name() = 0;
  virtual Data *compute(Data *input_) = 0;
};

class StateComputation: public ManagedObject
{
public:
  virtual const char *name() = 0;
  virtual void *compute(Data *input_, StateChangeRepository *state_change_repository_, void* state_change_Respository_helper_, State *state_, void *none, Data **data_out) = 0;
  virtual size_t get_number_of_state_change_builders() = 0;
  virtual StateChangeBuilder *get_state_change_builder(size_t idx_) = 0;
};
}

#endif // __COMPUTATION_H__
