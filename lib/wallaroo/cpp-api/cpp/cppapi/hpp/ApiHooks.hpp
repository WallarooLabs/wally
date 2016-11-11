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


#ifndef __APIHOOKS_HPP__
#define __APIHOOKS_HPP__


#include <cstddef>
#include "Computation.hpp"
#include "Serializable.hpp"
#include "Data.hpp"
#include "ManagedObject.hpp"
#include "SinkEncoder.hpp"
#include "SourceDecoder.hpp"
#include "State.hpp"
#include "StateChange.hpp"
#include "StateChangeRepository.hpp"
#include "StateChangeBuilder.hpp"

extern "C" {
extern wallaroo::Data *w_computation_compute(wallaroo::Computation *computation_, wallaroo::Data *data_);
extern const char *w_computation_get_name(wallaroo::Computation *computation);

extern void *w_state_computation_compute(wallaroo::StateComputation *state_computation_, wallaroo::Data *data_,
                                         wallaroo::StateChangeRepository *state_change_repo_,
                                         void *state_change_repository_helper_,
                                         wallaroo::State *state_,
                                         void *none_);
extern const char *w_state_computation_get_name(wallaroo::StateComputation *state_computation_);
extern size_t w_state_computation_get_number_of_state_change_builders(wallaroo::StateComputation *state_computaton_);
extern wallaroo::StateChangeBuilder *w_state_computation_get_state_change_builder(wallaroo::StateComputation *state_computation_, uint64_t idx_);

extern size_t w_serializable_serialize_get_size(wallaroo::Serializable* serializable_);
extern void w_serializable_serialize(wallaroo::Serializable* serializable_, char* bytes_, size_t sz_);
extern wallaroo::Serializable* w_serializable_deserialize (char* bytes_, size_t sz_);

extern size_t w_sink_encoder_get_size(wallaroo::SinkEncoder *sink_encoder,
  wallaroo::EncodableData *data_);
extern void w_sink_encoder_encode(wallaroo::SinkEncoder *sink_encoder,
  wallaroo::EncodableData *data_, char *bytes);

extern size_t w_source_decoder_header_length(wallaroo::SourceDecoder *source_decoder);
extern size_t w_source_decoder_payload_length(wallaroo::SourceDecoder *source_decoder, char *bytes);
extern wallaroo::Data *w_source_decoder_decode(wallaroo::SourceDecoder *source_decoder, char *bytes, size_t sz_);

extern const char *w_state_change_get_name(wallaroo::StateChange *state_change_);
extern uint64_t w_state_change_get_id(wallaroo::StateChange *state_change_);
extern void w_state_change_apply(wallaroo::StateChange *state_change_, wallaroo::State *state_);
extern size_t w_state_change_get_log_entry_size(wallaroo::StateChange *state_change_);
extern void w_state_change_to_log_entry(wallaroo::StateChange *state_change_, char *bytes_);
extern size_t w_state_change_get_log_entry_size_header_size(wallaroo::StateChange *state_change_);
extern size_t w_state_change_read_log_entry_size_header(wallaroo::StateChange *state_change_, char *bytes_);
extern bool w_state_change_read_log_entry(wallaroo::StateChange *state_change_, char *bytes_);

extern wallaroo::StateChange *w_state_change_builder_build(wallaroo::StateChangeBuilder *state_change_builder_, uint64_t id_);

extern void *w_state_change_repository_lookup_by_name(void *state_change_repository_helper_, void *state_change_repository_, const char *name_);
extern wallaroo::StateChange *w_state_change_get_state_change_object(void *state_change_repository_helper_, void *state_change_);
extern void *w_stateful_computation_get_return(void *state_change_repository_helper_, wallaroo::Data* data_, void *state_change_);

extern void w_managed_object_delete(wallaroo::ManagedObject const *obj_);
}

#endif //WALLAROOCPPAPI_APIHOOKS_HPP
