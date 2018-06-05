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

use "collections"
use "wallaroo/core/boundary"
use "wallaroo/core/initialization"
use "wallaroo/core/routing"
use "wallaroo/core/topology"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/watermarking"


actor DummyProducer is Producer
  // Producer
  fun ref route_to(c: Consumer): (Route | None) =>
    None

  fun ref next_sequence_id(): SeqId =>
    0

  fun ref current_sequence_id(): SeqId =>
    0

  be unknown_key(state_name: String, key: Key, data: Any val) =>
    None

  be update_keyed_route(state_name: String, key: Key, step: Step,
    step_id: StepId)
  =>
    None

  be remove_route_to_consumer(c: Consumer) =>
    None

  // Muteable
  be mute(c: Consumer) =>
    None

  be unmute(c: Consumer) =>
    None

  // Ackable
  fun ref _acker(): Acker =>
    Acker

  be update_watermark(route_id: RouteId, seq_id: SeqId) =>
    None

  fun ref flush(low_watermark: SeqId) =>
    None

  // AckRequester
  be request_ack() =>
    None

  // InFlightAckRequester
  be receive_in_flight_ack(request_id: RequestId) =>
    None
  be receive_in_flight_resume_ack(request_id: RequestId) =>
    None

  be try_finish_in_flight_request_early(requester_id: StepId) =>
    None

  // Initializable
  be application_begin_reporting(initializer: LocalTopologyInitializer) =>
    None

  be application_created(initializer: LocalTopologyInitializer,
    omni_router: OmniRouter)
  =>
    None

  be application_initialized(initializer: LocalTopologyInitializer) =>
    None

  be application_ready_to_work(initializer: LocalTopologyInitializer) =>
    None
