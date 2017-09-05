// Copyright 2017 The Wallaroo Authors.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
// implied. See the License for the specific language governing
// permissions and limitations under the License.

#ifndef __COMPUTATION_HPP__
#define __COMPUTATION_HPP__

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
  virtual void *compute(Data *input_,
    StateChangeRepository *state_change_repository_,
    void* state_change_Respository_helper_, State *state_, void *none) = 0;
  virtual size_t get_number_of_state_change_builders() = 0;
  virtual StateChangeBuilder *get_state_change_builder(size_t idx_) = 0;
};
}

#endif // __COMPUTATION_HPP__
