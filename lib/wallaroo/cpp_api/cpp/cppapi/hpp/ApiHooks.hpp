#ifndef __APIHOOKS_HPP__
#define __APIHOOKS_HPP__

#include <cstddef>
#include "Computation.hpp"
#include "Serializable.hpp"
#include "Data.hpp"
#include "Key.hpp"
#include "PartitionFunction.hpp"
#include "ManagedObject.hpp"
#include "SinkEncoder.hpp"
#include "SourceDecoder.hpp"
#include "State.hpp"
#include "StateChange.hpp"
#include "StateChangeRepository.hpp"
#include "StateChangeBuilder.hpp"

using namespace wallaroo;

extern "C" {

extern Data *w_computation_compute(Computation *computation_, Data *data_);
extern const char *w_computation_get_name(Computation *computation_);

extern void *w_state_computation_compute(StateComputation *state_computation_,
  Data *data_, StateChangeRepository *state_change_repo_,
  void *state_change_repository_helper_, State *state_, void *none_);
extern const char *w_state_computation_get_name(
  StateComputation *state_computation_);
extern size_t w_state_computation_get_number_of_state_change_builders(
  StateComputation *state_computaton_);
extern StateChangeBuilder *w_state_computation_get_state_change_builder(
  StateComputation *state_computation_, uint64_t idx_);

extern size_t w_serializable_serialize_get_size(Serializable* serializable_);
extern void w_serializable_serialize(Serializable* serializable_, char* bytes_,
  size_t sz_);
extern Serializable* w_serializable_deserialize (char* bytes_, size_t sz_);

extern size_t w_sink_encoder_get_size(SinkEncoder *sink_encoder_,
  EncodableData *data_);
extern void w_sink_encoder_encode(SinkEncoder *sink_encoder_,
  EncodableData *data_, char *bytes);

extern size_t w_source_decoder_header_length(SourceDecoder *source_decoder_);
extern size_t w_source_decoder_payload_length(SourceDecoder *source_decoder_,
  char *bytes_);
extern Data *w_source_decoder_decode(SourceDecoder *source_decoder_, char *bytes_,
  size_t sz_);

extern const char *w_state_change_get_name(StateChange *state_change_);
extern uint64_t w_state_change_get_id(StateChange *state_change_);
extern void w_state_change_apply(StateChange *state_change_, State *state_);
extern size_t w_state_change_get_log_entry_size(StateChange *state_change_);
extern void w_state_change_to_log_entry(
  StateChange *state_change_, char *bytes_);
extern size_t w_state_change_get_log_entry_size_header_size(
  StateChange *state_change_);
extern size_t w_state_change_read_log_entry_size_header(
  StateChange *state_change_, char *bytes_);
extern bool w_state_change_read_log_entry(StateChange *state_change_,
  char *bytes_);

extern StateChange *w_state_change_builder_build(
  StateChangeBuilder *state_change_builder_, uint64_t id_);

extern void *w_state_change_repository_lookup_by_name(
  void *state_change_repository_helper_, void *state_change_repository_,
  const char *name_);
extern StateChange *w_state_change_get_state_change_object(
  void *state_change_repository_helper_, void *state_change_);
extern void *w_stateful_computation_get_return(
  void *state_change_repository_helper_, Data* data_, void *state_change_);

extern uint64_t w_key_hash(Key *key_);
extern bool w_key_eq(Key *key_, Key *other_);

extern Key *w_partition_function_partition(
  PartitionFunction *partition_function_, Data *data_);

extern uint64_t w_partition_function_u64_partition(
  PartitionFunctionU64 *partition_function_u64_, Data *data_);

extern void w_managed_object_delete(ManagedObject const *obj_);

}

#endif // __APIHOOKS_HPP__
