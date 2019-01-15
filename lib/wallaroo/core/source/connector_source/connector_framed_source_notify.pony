/*

Copyright 2017-2019 The Wallaroo Authors.

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
use "wallaroo/core/partitioning"
use "wallaroo/ent/data_receiver"
use "wallaroo/ent/recovery"
use "wallaroo_labs/mort"
use "wallaroo/core/messages"
use "wallaroo/core/metrics"
use "wallaroo/core/routing"
use "wallaroo/core/source"
use "wallaroo/core/topology"


class ConnectorSourceNotify[In: Any val]
  let _source_id: RoutingId
  let _env: Env
  let _auth: AmbientAuth
  let _msg_id_gen: MsgIdGenerator = MsgIdGenerator
  var _header: Bool = true
  let _pipeline_name: String
  let _source_name: String
  let _handler: FramedSourceHandler[In] val
  let _runner: Runner
  var _router: Router
  let _metrics_reporter: MetricsReporter
  let _header_size: USize

  // Watermark !@ How do we handle this respecting per-connector-type policies
  var _watermark_ts: U64 = 0

  new iso create(source_id: RoutingId, pipeline_name: String, env: Env,
    auth: AmbientAuth, handler: FramedSourceHandler[In] val,
    runner_builder: RunnerBuilder, partitioner_builder: PartitionerBuilder,
    router': Router, metrics_reporter: MetricsReporter iso,
    event_log: EventLog, target_router: Router)
  =>
    _source_id = source_id
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _env = env
    _auth = auth
    _handler = handler
    _runner = runner_builder(event_log, auth, None,
      target_router, partitioner_builder)
    _router = router'
    _metrics_reporter = consume metrics_reporter
    _header_size = _handler.header_length()

  fun routes(): Map[RoutingId, Consumer] val =>
    _router.routes()

  fun ref received(source: ConnectorSource[In] ref, data: Array[U8] iso): Bool =>
    if _header then
      try
        let payload_size: USize = _handler.payload_length(consume data)?

        source.expect(payload_size)
        _header = false
      else
        Fail()
      end
      true
    else
      _metrics_reporter.pipeline_ingest(_pipeline_name, _source_name)
      let ingest_ts = WallClock.nanoseconds()
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
          let decode_end_ts = WallClock.nanoseconds()
          _metrics_reporter.step_metric(_pipeline_name,
            "Decode Time in Connector Source", latest_metrics_id, ingest_ts,
            decode_end_ts)
          latest_metrics_id = latest_metrics_id + 1

          ifdef "trace" then
            @printf[I32](("Msg decoded at " + _pipeline_name +
              " source\n").cstring())
          end

          let msg_uid = _msg_id_gen()

          // TODO: We need a way to determine the key based on the policy
          // for any particular connector. For example, the Kafka connector
          // needs a way to provide the Kafka key here.
          let initial_key = msg_uid.string()

          // TOOD: We need a way to assign watermarks based on the policy
          // for any particular connector.
          if ingest_ts > _watermark_ts then
            _watermark_ts = ingest_ts
          end

          if decoded isnt None then
            _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
              consume initial_key, ingest_ts, _watermark_ts, _source_id,
              source, _router, msg_uid, None, decode_end_ts,
              latest_metrics_id, ingest_ts, _metrics_reporter)
          else
            (true, ingest_ts)
          end
        else
          @printf[I32](("Unable to decode message at " + _pipeline_name +
            " source\n").cstring())
          ifdef debug then
            Fail()
          end
          (true, ingest_ts)
        end

      if is_finished then
        let end_ts = WallClock.nanoseconds()
        let time_spent = end_ts - ingest_ts

        ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(_pipeline_name,
            "Before end at Connector Source", 9999,
            last_ts, end_ts)
        end

        _metrics_reporter.pipeline_metric(_pipeline_name, time_spent +
          pipeline_time_spent)
        _metrics_reporter.worker_metric(_pipeline_name, time_spent)
      end

      source.expect(_header_size)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref update_router(router': Router) =>
    _router = router'

  fun ref update_boundaries(obs: box->Map[String, OutgoingBoundary]) =>
    match _router
    | let p_router: StatePartitionRouter =>
      _router = p_router.update_boundaries(_auth, obs)
    else
      ifdef "trace" then
        @printf[I32](("FramedSourceNotify doesn't have StatePartitionRouter." +
          " Updating boundaries is a noop for this kind of Source.\n")
          .cstring())
      end
    end

  fun ref accepted(source: ConnectorSource[In] ref) =>
    @printf[I32]((_source_name + ": accepted a connection\n").cstring())
    _header = true
    source.expect(_header_size)

  fun ref closed(source: ConnectorSource[In] ref) =>
    @printf[I32]("ConnectorSource connection closed\n".cstring())

  fun ref connecting(conn: ConnectorSource[In] ref, count: U32) =>
    """
    Called if name resolution succeeded for a ConnectorSource and we are now
    waiting for a connection to the server to succeed. The count is the number
    of connections we're trying. The notifier will be informed each time the
    count changes, until a connection is made or connect_failed() is called.
    """
    None

  fun ref connected(conn: ConnectorSource[In] ref) =>
    """
    Called when we have successfully connected to the server.
    """
    None

  fun ref connect_failed(conn: ConnectorSource[In] ref) =>
    """
    Called when we have failed to connect to all possible addresses for the
    server. At this point, the connection will never be established.
    """
    None

  fun ref expect(conn: ConnectorSource[In] ref, qty: USize): USize =>
    """
    Called when the connection has been told to expect a certain quantity of
    bytes. This allows nested notifiers to change the expected quantity, which
    allows a lower level protocol to handle any framing (e.g. SSL).
    """
    qty
