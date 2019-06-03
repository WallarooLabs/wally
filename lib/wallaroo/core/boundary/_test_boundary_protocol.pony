/*

Copyright 2018 The Wallaroo Authors.

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
use "files"
use "ponytest"
use "promises"
use "random"
use "time"
use "wallaroo/core/aggregations"
use "wallaroo/core/barrier"
use "wallaroo/core/common"
use "wallaroo/core/messages"
use "wallaroo/core/state"
use "wallaroo/core/tcp_actor"
use "wallaroo/core/topology"
use "wallaroo/test_components"
use "wallaroo_labs/time"


actor _TestBoundaryProtocol is TestList
  new create(env: Env) => PonyTest(env, this)
  new make() => None
  fun tag tests(test: PonyTest) =>
    test(_ForwardDataMessages)

primitive _OutgoingBoundaryTestBuilder
  fun apply(auth: AmbientAuth, tcp_handler_builder: TestableTCPHandlerBuilder):
    OutgoingBoundary
  =>
    OutgoingBoundary(auth, "w1", "w2", tcp_handler_builder,
      MetricsReporterDummyBuilder(), "127.0.0.1", "6666")

class iso _ForwardDataMessages is UnitTest
  fun name(): String => "boundary/protocol/_ForwardDataMessages"

  fun apply(h: TestHelper) ? =>
    // Send in data messages to identity computation step
    // Emit those same messages immediately

    // given
    let auth = h.env.root as AmbientAuth
    var boundary_seq_id: SeqId = 1

    let r_file_path = FilePath(auth, "./test_r_file")?
    let w_file_path = FilePath(auth, "./test_w_file")?
    let rw_builder = FileTestReaderWriterBuilder(r_file_path, w_file_path)
    let tcp_handler_builder = MockTCPHandlerBuilder(rw_builder)
    let boundary = _OutgoingBoundaryTestBuilder(auth, tcp_handler_builder)

    // when
    let delivery_msg = ForwardMsg[USize](0, "w1", 100, "key", 0, 0,
      "", ProxyAddress("w2", 0), 0, None)

    boundary.forward(delivery_msg, 0, 0, DummyProducer, boundary_seq_id,
        0, 0, 0)

  // be forward(delivery_msg: DeliveryMsg, pipeline_time_spent: U64,
  //   i_producer_id: RoutingId, i_producer: Producer, i_seq_id: SeqId,
  //   latest_ts: U64, metrics_id: U16, worker_ingress_ts: U64)



  //   let test_finished_msg: USize = -1
  //   let auth = h.env.root as AmbientAuth
  //   let expected: Array[(USize | BarrierToken)] val =
  //     recover [1; 2; 3; 4; 5; 6; 7; 8; 9; 10] end
  //   let oc = TestOutputCollector[USize](h, expected, test_finished_msg)
  //   let step = TestOutputCollectorStepBuilder[USize](h.env, auth, oc)
  //   let upstream1 = DummyProducer
  //   let upstream1_id: RoutingId = 1
  //   let upstream2 = DummyProducer
  //   let upstream2_id: RoutingId = 2
  //   step.register_producer(upstream1_id, upstream1)
  //   step.register_producer(upstream2_id, upstream2)

  //   // when
  //   let inputs1: Array[USize] val = recover [1; 2; 3; 4; 5] end
  //   let inputs2: Array[USize] val = recover [6; 7; 8; 9; 10] end
  //   TestStepSender[USize].send_seq(step, inputs1, upstream1_id, upstream1)
  //   TestStepSender[USize].send_seq(step, inputs2, upstream2_id, upstream2)
  //   TestStepSender[USize].send(step, test_finished_msg, upstream1_id,
  //     upstream1)

  //   // then
  //   // TestOutputCollector checks against expected

  //   h.long_test(1_000_000_000)
