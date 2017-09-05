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

#ifndef __WALLAROO_SINK_ENCODER_H__
#define __WALLAROO_SINK_ENCODER_H__

#include <cstdlib>
#include "ManagedObject.hpp"
#include "Data.hpp"

namespace wallaroo
{
class SinkEncoder: public ManagedObject {
public:
  virtual size_t get_size(Data *data_) = 0;
  virtual void encode(Data *data_, char *bytes_) = 0;
};
}

#endif // __WALLAROO_SINK_ENCODER_H__
