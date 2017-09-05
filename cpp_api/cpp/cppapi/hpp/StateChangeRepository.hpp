/*

Copyright 2017 The Wallaroo Authors.

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

     http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
 implied. See the License for the specific language governing
 permissions and limitations under the License.

*/

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
