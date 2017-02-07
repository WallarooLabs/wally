#include "ApiHooks.hpp"
#include "Computation.hpp"
#include "Data.hpp"
#include "Key.hpp"
#include "PartitionFunction.hpp"
#include "Serializable.hpp"
#include "ManagedObject.hpp"
#include "SinkEncoder.hpp"
#include "SourceDecoder.hpp"
#include "State.hpp"
#include "StateChange.hpp"
#include "StateChangeRepository.hpp"
#include "StateChangeBuilder.hpp"

using namespace wallaroo;

extern "C"
{
// These functions are generated when building the Wallaroo application.
  void* pony_CPPStateChangeRepositoryHelper_lookup_by_name(void* self,
    void* sc_repo, const char* name_p);
  void* pony_CPPStateChangeRepositoryHelper_get_state_change_object(
  void *state_change_repository_helper_, void* state_change_);
  void* pony_CPPStateChangeRepositoryHelper_get_stateful_computation_return(
    void *state_change_repository_helper_, void* data_, void* state_change_);

extern Data *w_computation_compute(Computation *computation_, Data *data_)
{
  return computation_->compute(data_);
}

extern const char *w_computation_get_name(Computation *computation_)
{
  return computation_->name();
}

extern void *w_state_computation_compute(StateComputation *state_computation_,
  Data *data_, StateChangeRepository *state_change_repo_,
  void *state_change_repository_helper_, State *state_, void *none_)
{
  return state_computation_->compute(data_, state_change_repo_,
    state_change_repository_helper_, state_, none_);
}

extern const char *w_state_computation_get_name(
  StateComputation *state_computation_)
{
  return state_computation_->name();
}

extern size_t w_state_computation_get_number_of_state_change_builders(
  StateComputation *state_computation_)
{
  return state_computation_->get_number_of_state_change_builders();
}

extern StateChangeBuilder *w_state_computation_get_state_change_builder(
  StateComputation *state_computation_, uint64_t idx_)
{
  return state_computation_->get_state_change_builder(idx_);
}

extern size_t w_serializable_serialize_get_size(Serializable* serializable_)
{
  return serializable_->serialize_get_size();
}

extern void w_serializable_serialize(Serializable* serializable_, char* bytes_,
  size_t sz_)
{
  serializable_->serialize(bytes_, sz_);
}

extern size_t w_sink_encoder_get_size(SinkEncoder *sink_encoder_,
  EncodableData *data_)
{
  return sink_encoder_->get_size(data_);
}

extern void w_sink_encoder_encode(SinkEncoder *sink_encoder_,
  EncodableData *data_, char *bytes_)
{
  sink_encoder_->encode(data_, bytes_);
}

extern size_t w_source_decoder_header_length(SourceDecoder *source_decoder_)
{
  return source_decoder_->header_length();
}

extern size_t w_source_decoder_payload_length(SourceDecoder *source_decoder_,
  char *bytes_)
{
  return source_decoder_->payload_length(bytes_);
}

extern Data *w_source_decoder_decode(SourceDecoder *source_decoder_,
  char *bytes_, size_t sz_)
{
  return source_decoder_->decode(bytes_, sz_);
}

extern const char *w_state_change_get_name(StateChange *state_change_)
{
  return state_change_->name();
}

extern uint64_t w_state_change_get_id(StateChange *state_change_)
{
  return state_change_->id();
}

extern void w_state_change_apply(StateChange *state_change_, State *state_)
{
  return state_change_->apply(state_);
}

extern size_t w_state_change_get_log_entry_size(StateChange *state_change_)
{
  return state_change_->get_log_entry_size();
}

extern void w_state_change_to_log_entry(StateChange *state_change_,
  char *bytes_)
{
  state_change_->to_log_entry(bytes_);
}

extern size_t w_state_change_get_log_entry_size_header_size(
  StateChange *state_change_)
{
  return state_change_->get_log_entry_size_header_size();
}

extern size_t w_state_change_read_log_entry_size_header(
  StateChange *state_change_, char *bytes_)
{
  return state_change_->read_log_entry_size_header(bytes_);
}

extern bool w_state_change_read_log_entry(StateChange *state_change_,
  char *bytes_)
{
  return state_change_->read_log_entry(bytes_);
}

extern StateChange *w_state_change_builder_build(
  StateChangeBuilder *state_change_builder_, uint64_t id_)
{
  return state_change_builder_->build(id_);
}

extern void *w_state_change_repository_lookup_by_name(
  void *state_change_repository_helper_, void *state_change_repository_,
  const char *name_)
{
  return (void *)
    pony_CPPStateChangeRepositoryHelper_lookup_by_name(
      state_change_repository_helper_, state_change_repository_, name_);
}

extern StateChange *w_state_change_get_state_change_object(
  void *state_change_repository_helper_, void *state_change_)
{
  return (StateChange *)
    pony_CPPStateChangeRepositoryHelper_get_state_change_object(
      state_change_repository_helper_, state_change_);
}

void *w_stateful_computation_get_return(void *state_change_repository_helper_,
  Data* data_, void *state_change_)
{
  return
    pony_CPPStateChangeRepositoryHelper_get_stateful_computation_return(
      state_change_repository_helper_, data_, state_change_);
}

extern uint64_t w_key_hash(Key *key_)
{
  return key_->hash();
}

extern bool w_key_eq(Key *key_, Key *other_)
{
  return key_->eq(other_);
}

extern Key *w_partition_function_partition(
  PartitionFunction *partition_function_, Data *data_)
{
  return partition_function_->partition(data_);
}

extern uint64_t w_partition_function_u64_partition(
  PartitionFunctionU64 *partition_function_, Data *data_)
{
  return partition_function_->partition(data_);
}

extern void w_managed_object_delete(ManagedObject const *obj_)
{
  delete obj_;
}

}
