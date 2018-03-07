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
use "time"
use "wallaroo_labs/time"
use "wallaroo/core/boundary"
use "wallaroo/core/common"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"


primitive TCPFramedSourceNotifyBuilder[In: Any val]
  fun apply(pipeline_name: String, env: Env, auth: AmbientAuth,
    handler: FramedSourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router,
    pre_state_target_ids: Array[StepId] val = recover Array[StepId] end):
    SourceNotify iso^
  =>
    TCPFramedSourceNotify[In](pipeline_name, env, auth, handler,
      runner_builder, router, consume metrics_reporter, event_log,
      target_router, pre_state_target_ids)

class TCPFramedSourceNotify[In: Any val] is TCPSourceNotify
  let _env: Env
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
  var _header: Bool = true
  let _pipeline_name: String
  let _source_name: String
  let _handler: FramedSourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _omni_router: OmniRouter = EmptyOmniRouter
  let _metrics_reporter: MetricsReporter
  let _header_size: USize

  new iso create(pipeline_name: String, env: Env, auth: AmbientAuth,
    handler: FramedSourceHandler[In] val,
    runner_builder: RunnerBuilder, router: Router,
    metrics_reporter: MetricsReporter iso, event_log: EventLog,
    target_router: Router,
    pre_state_target_ids: Array[StepId] val = recover Array[StepId] end)
  =>
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _env = env
    _handler = handler
    _runner = runner_builder(event_log, auth, None,
      target_router, pre_state_target_ids)
    _router = _runner.clone_router_and_set_input_type(router)
    _metrics_reporter = consume metrics_reporter
    _header_size = _handler.header_length()

  fun routes(): Array[Consumer] val =>
    _router.routes()

  fun ref received(conn: TCPSource ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let payload_size: USize = _handler.payload_length(consume data)?

        conn.expect(payload_size)
        _header = false
      else
        Fail()
      end
      true
    else
      _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
      let ingest_ts = Time.nanos()
      let pipeline_time_spent: U64 = 0
      var latest_metrics_id: U16 = 1

      ifdef "trace" then
        @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
      end

      (let is_finished, let last_ts) =
        try
          let decoded =
            try
              _handler.decode(consume data)?
            else
              ifdef debug then
                @printf[I32]("Error decoding message at source\n".cstring())
              end
              error
            end
          let decode_end_ts = Time.nanos()
          _metrics_reporter.step_metric(_pipeline_name,
            "Decode Time in TCP Source", latest_metrics_id, ingest_ts,
            decode_end_ts)
          latest_metrics_id = latest_metrics_id + 1

          ifdef "trace" then
            @printf[I32](("Msg decoded at " + _pipeline_name +
              " source\n").cstring())
          end
          _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
            conn, _router, _omni_router, _msg_id_gen(), None,
            decode_end_ts, latest_metrics_id, ingest_ts, _metrics_reporter)
        else
          @printf[I32](("Unable to decode message at " + _pipeline_name +
            " source\n").cstring())
          ifdef debug then
            Fail()
          end
          (true, ingest_ts)
        end

      if is_finished then
        let end_ts = Time.nanos()
        let time_spent = end_ts - ingest_ts

        ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(_pipeline_name,
            "Before end at TCP Source", 9999,
            last_ts, end_ts)
        end

        _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
          pipeline_time_spent)
        _metrics_reporter.worker_metric(_pipeline_name, time_spent)
      end

      conn.expect(_header_size)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref update_router(router: Router) =>
    _router = router

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: PartitionRouter =>
      _router = p_router.update_boundaries(obs)
    else
      ifdef "trace" then
        @printf[I32](("FramedSourceNotify doesn't have PartitionRouter." +
          " Updating boundaries is a noop for this kind of Source.\n")
          .cstring())
      end
    end

  fun ref accepted(conn: TCPSource ref) =>
    @printf[I32]((_source_name + ": accepted a connection\n").cstring())
    conn.set_so_rcvbuf(4456)
    conn.expect(_header_size)

  fun ref closed(conn: TCPSource ref) =>
    @printf[I32]("TCPSource connection closed\n".cstring())

  // TODO: implement connect_failed
