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

#ifndef __WALLAROO_SOURCE_DECODER_H__
#define __WALLAROO_SOURCE_DECODER_H__

#include "ManagedObject.hpp"
#include "Data.hpp"

namespace wallaroo
{
class SourceDecoder: public ManagedObject
{
public:
  virtual std::size_t header_length() = 0;
  virtual std::size_t payload_length(char *bytes_) = 0;
  virtual Data *decode(char *bytes_, size_t sz_) = 0;
};
}

#endif // __WALLAROO_SOURCE_DECODER_H__
