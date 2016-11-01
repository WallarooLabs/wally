/*************************************************************************
 * 
 * SENDENCE LLC CONFIDENTIAL
 * __________________
 * 
 *  [2016] Sendence LLC
 *  All Rights Reserved.
 *  Copyright (c) 2016 Sendence LLC All rights reserved.
 * 
 * NOTICE:  All information contained herein is, and remains
 * the property of Sendence LLC and its suppliers,
 * if any.  The intellectual and technical concepts contained
 * herein are proprietary to Sendence LLC and its suppliers 
 * and may be covered by U.S. and Foreign Patents, patents in 
 * process, and are protected by trade secret or copyright law.
 * Dissemination of this information or reproduction of this material
 * is strictly forbidden unless prior written permission is obtained
 * from Sendence LLC.
 *
 * Copyright (c) 2016 Sendence LLC All rights reserved.
 */


#include "ApiHooks.hpp"
#include "Computation.hpp"
#include "Data.hpp"
#include "ManagedObject.hpp"
#include "SinkEncoder.hpp"
#include "SourceDecoder.hpp"
#include "State.hpp"
#include "StateChange.hpp"
#include "StateChangeRepository.hpp"
#include "StateChangeBuilder.hpp"

extern "C"
{
//------------------------------------------------------------------------
//
extern wallaroo::Data *w_computation_compute(wallaroo::Computation *computation_, wallaroo::Data *data_)
{
  return computation_->compute(data_);
}

extern char *w_computation_get_name(wallaroo::Computation *computation_)
{
  return computation_->name();
}

extern wallaroo::Data *w_state_computation_compute(wallaroo::StateComputation *state_computation_,
                                                   wallaroo::Data *data_,
                                                   wallaroo::StateChangeRepository *state_change_repo_,
                                                   wallaroo::State *state_)
{
  return state_computation_->compute(data_, state_change_repo_, state_);
}

extern char *w_state_computation_get_name(wallaroo::StateComputation *state_computation_)
{
  return state_computation_->name();
}

extern size_t w_state_computation_get_number_of_state_change_builders(wallaroo::StateComputation *state_computation_)
{
  return state_computation_->get_number_of_state_change_builders();
}

extern wallaroo::StateChangeBuilder *w_state_computation_get_state_change_builder(wallaroo::StateComputation *state_computation_, uint64_t idx_)
{
  return state_computation_->get_state_change_builder(idx_);
}

extern size_t w_data_serialize_get_size(wallaroo::Data* data_)
{
  return data_->serialize_get_size();
}

extern void w_data_serialize(wallaroo::Data* data_, char* bytes_, size_t sz_)
{
  data_->serialize(bytes_, sz_);
}

extern size_t w_sink_encoder_get_size(wallaroo::SinkEncoder *sink_encoder,
  wallaroo::Data *data_)
{
  return sink_encoder->get_size(data_);
}

extern void w_sink_encoder_encode(wallaroo::SinkEncoder *sink_encoder,
  wallaroo::Data *data_, char *bytes)
{
  sink_encoder->encode(data_, bytes);
}

extern size_t w_source_decoder_header_length(wallaroo::SourceDecoder *source_decoder)
{
  return source_decoder->header_length();
}

extern size_t w_source_decoder_payload_length(wallaroo::SourceDecoder *source_decoder, char *bytes)
{
  return source_decoder->payload_length(bytes);
}

extern wallaroo::Data *w_source_decoder_decode(wallaroo::SourceDecoder *source_decoder,
  char *bytes, size_t sz_)
{
  return source_decoder->decode(bytes, sz_);
}

extern void w_managed_object_delete(wallaroo::ManagedObject const *obj_)
{
  delete obj_;
}

extern char *w_state_change_get_name(wallaroo::StateChange *state_change_)
{
  return state_change_->name();
}

extern uint64_t w_state_change_get_id(wallaroo::StateChange *state_change_)
{
  return state_change_->id();
}

extern void w_state_change_apply(wallaroo::StateChange *state_change_, wallaroo::State *state_)
{
  return state_change_->apply(state_);
}

extern size_t w_state_change_get_log_entry_size(wallaroo::StateChange *state_change_)
{
  return state_change_->get_log_entry_size();
}

extern void w_state_change_to_log_entry(wallaroo::StateChange *state_change_, char *bytes_)
{
  state_change_->to_log_entry(bytes_);
}

extern size_t w_state_change_get_log_entry_size_header_size(wallaroo::StateChange *state_change_)
{
  return state_change_->get_log_entry_size_header_size();
}

extern size_t w_state_change_read_log_entry_size_header(wallaroo::StateChange *state_change_, char *bytes_)
{
  return state_change_->read_log_entry_size_header(bytes_);
}

extern bool w_state_change_read_log_entry(wallaroo::StateChange *state_change_, char *bytes_)
{
  return state_change_->read_log_entry(bytes_);
}

}
