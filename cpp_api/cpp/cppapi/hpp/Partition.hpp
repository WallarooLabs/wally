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

#ifndef __PARTITION_HPP__
#define __PARTITION_HPP__

#include "PartitionFunction.hpp"
#include "Key.hpp"

namespace wallaroo {
  class Partition
  {
  public:
    virtual PartitionFunction *get_partition_function() = 0;
    virtual size_t get_number_of_keys() = 0;
    virtual Key *get_key(size_t idx_) = 0;
  };

  class PartitionU64
  {
  public:
    virtual PartitionFunctionU64 *get_partition_function() = 0;
    virtual size_t get_number_of_keys() = 0;
    virtual uint64_t get_key(size_t idx_) = 0;
  };
}


#endif // __PARTITION_HPP__
