#include "ApiHooks.hpp"
#include "Application.hpp"
#include "SourceDecoder.hpp"
#include "SinkEncoder.hpp"
#include "Computation.hpp"
#include "ComputationBuilder.hpp"
#include "State.hpp"
#include "PartitionFunction.hpp"
#include "Key.hpp"

using namespace wallaroo;

extern "C"
{
  void pony_CPPApplicationBuilder_create_application(void* self, void* name_);
  void pony_CPPApplicationBuilder_new_pipeline(void* self, void* name_, void* source_decoder_);
  void pony_CPPApplicationBuilder_to(void* self, void *computation_builder);
  void pony_CPPApplicationBuilder_to_stateful(
    void* self,
    void *computation,
    void *state_builder_,
    void *state_name);
  void pony_CPPApplicationBuilder_to_state_partition(
    void* self,
    void *computation,
    void *state_builder_,
    void *state_name,
    void *partition,
    bool multi_worker);
  void pony_CPPApplicationBuilder_to_state_partition_u64(
    void* self,
    void *computation,
    void *state_builder_,
    void *state_name,
    void *partition,
    bool multi_worker);
  void pony_CPPApplicationBuilder_to_sink(void* self, void *sink_encoder);
  void pony_CPPApplicationBuilder_build(void* self);
  void pony_CPPApplicationBuilder_done(void* self);
}

Application::Application(void *application_builder_):
  m_application_builder(application_builder_)
{
}

Application::~Application()
{
}

Application *Application::create_application(const char *name_)
{
  pony_CPPApplicationBuilder_create_application(
    m_application_builder,
    (void *) name_);
  return this;
}

Application *Application::new_pipeline(
  const char* pipeline_name_,
  SourceDecoder *source_decoder_)
{
  pony_CPPApplicationBuilder_new_pipeline(
    m_application_builder, (void *) pipeline_name_, (void *) source_decoder_);

  return this;
}

Application *Application::to(ComputationBuilder *computation_builder_)
{
  pony_CPPApplicationBuilder_to(
    m_application_builder, (void *) computation_builder_);
  return this;
}

Application *Application::to_stateful(
  StateComputation *state_computation_,
  StateBuilder *state_builder_,
  const char* state_name_)
{
  pony_CPPApplicationBuilder_to_stateful(
    m_application_builder,
    (void *) state_computation_,
    (void *) state_builder_,
    (void *) state_name_
    );
  return this;
}

Application *Application::to_state_partition(
  StateComputation *state_computation_,
  StateBuilder *state_builder_,
  const char* state_name_,
  Partition *partition_,
  bool multi_worker_ = false)
{
  pony_CPPApplicationBuilder_to_state_partition(
    m_application_builder,
    (void *) state_computation_,
    (void *) state_builder_,
    (void *) state_name_,
    (void *) partition_,
    multi_worker_
    );
  return this;
}

Application *Application::to_state_partition_u64(
  StateComputation *state_computation_,
  StateBuilder *state_builder_,
  const char* state_name_,
  PartitionU64 *partition_,
  bool multi_worker_ = false)
{
  pony_CPPApplicationBuilder_to_state_partition_u64(
    m_application_builder,
    (void *) state_computation_,
    (void *) state_builder_,
    (void *) state_name_,
    (void *) partition_,
    multi_worker_
    );
  return this;
}

Application *Application::to_sink(SinkEncoder *sink_encoder_)
{
  pony_CPPApplicationBuilder_to_sink(
    m_application_builder,
    sink_encoder_
    );
  return this;
}

Application *Application::done()
{
  pony_CPPApplicationBuilder_done(m_application_builder);
  return this;
}
