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

#ifndef __SERIALIZABLE_HPP__
#define __SERIALIZABLE_HPP__

#include <cstddef>

namespace wallaroo
{
class Serializable
{
public:
  virtual void deserialize (char* bytes_) {}
  virtual void serialize (char* bytes_) {}
  virtual size_t serialize_get_size () { return 0; }
};
}
#endif // __SERIALIZABLE_HPP__
