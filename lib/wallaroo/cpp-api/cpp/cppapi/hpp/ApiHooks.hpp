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
#include "Data.hpp"
#include "ManagedObject.hpp"
#include "SinkEncoder.hpp"
#include "SourceDecoder.hpp"

extern "C" {
extern wallaroo::Data *w_computation_compute(wallaroo::Computation *computation_, wallaroo::Data *data_);
extern char *w_computation_get_name(wallaroo::Computation *computation);

extern wallaroo::Data *w_state_computation_compute(wallaroo::StateComputation *state_computation_, wallaroo::Data *data_, wallaroo::State *state_);
extern char *w_state_computation_get_name(wallaroo::StateComputation *state_computation_);

extern size_t w_data_serialize_get_size(wallaroo::Data* data_);
extern void w_data_serialize(wallaroo::Data* data_, char* bytes_, size_t sz_);
extern wallaroo::Data* w_data_deserialize (char* bytes_, size_t sz_);

extern size_t w_sink_encoder_get_size(wallaroo::SinkEncoder *sink_encoder,
  wallaroo::Data *data_);
extern void w_sink_encoder_encode(wallaroo::SinkEncoder *sink_encoder,
  wallaroo::Data *data_, char *bytes);

extern void w_source_decoder_encode(wallaroo::SourceDecoder *source_decoder,
  char *bytes);

extern void w_managed_object_delete(wallaroo::ManagedObject const *obj_);
}

#endif //WALLAROOCPPAPI_APIHOOKS_HPP
