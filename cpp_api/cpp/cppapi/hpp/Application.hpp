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
