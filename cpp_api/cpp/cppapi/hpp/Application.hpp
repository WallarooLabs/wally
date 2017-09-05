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

#ifndef __APPLICATION_HPP__
#define __APPLICATION_HPP__

#include "SourceDecoder.hpp"
#include "SinkEncoder.hpp"
#include "Computation.hpp"
#include "ComputationBuilder.hpp"
#include "State.hpp"
#include "StateBuilder.hpp"
#include "Partition.hpp"

namespace wallaroo {
  class Application
  {
  private:
    void *m_application_builder;
    const char *m_name;
  public:
    Application(void *application_builder_);
    ~Application();
    Application *create_application(const char *name_);
    Application *new_pipeline(
      const char* pipeline_name_,
      SourceDecoder *source_decoder_);
    Application *to(ComputationBuilder *computation_builder_);
    Application *to_stateful(
      StateComputation *state_computation_,
      StateBuilder *state_builder_,
      const char* state_name_);
    Application *to_state_partition(
      StateComputation *state_computation_,
      StateBuilder *state_builder_,
      const char* state_name_,
      Partition *partition_,
      bool multi_worker_);
    Application *to_state_partition_u64(
      StateComputation *state_computation_,
      StateBuilder *state_builder_,
      const char* state_name_,
      PartitionU64 *partition_,
      bool multi_worker_);
    Application *to_sink(SinkEncoder *sink_encoder_);
    Application *done();
  };
}

#endif // __LIBRARY_HPP__
