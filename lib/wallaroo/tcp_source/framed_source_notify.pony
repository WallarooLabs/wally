use "time"
use "sendence/guid"
use "sendence/wall_clock"
use "wallaroo/fail"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/resilience"
use "wallaroo/routing"
use "wallaroo/topology"


interface FramedSourceHandler[In: Any val]
  fun header_length(): USize
  fun payload_length(data: Array[U8] iso): USize ?
  fun decode(data: Array[U8] val): In ?

class FramedSourceNotify[In: Any val] is TCPSourceNotify
  let _guid_gen: GuidGenerator = GuidGenerator
  var _header: Bool = true
  let _pipeline_name: String
  let _source_name: String
  let _handler: FramedSourceHandler[In] val
  let _runner: Runner
  let _router: Router val
  let _omni_router: OmniRouter val = EmptyOmniRouter
  let _metrics_reporter: MetricsReporter
  let _header_size: USize

  new iso create(pipeline_name: String, handler: FramedSourceHandler[In] val,
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso, alfred: Alfred tag,
    target_router: Router val, pre_state_target_id: (U128 | None) = None)
  =>
    _pipeline_name = pipeline_name
    // TODO: Figure out how to name sources
    _source_name = pipeline_name + " source"
    _handler = handler
    _runner = runner_builder(alfred, None,
      target_router, pre_state_target_id)
    _router = _runner.clone_router_and_set_input_type(router)
    _metrics_reporter = consume metrics_reporter
    _header_size = _handler.header_length()

  fun routes(): Array[ConsumerStep] val =>
    _router.routes()

  fun ref received(conn: TCPSource ref, data: Array[U8] iso): Bool =>
    if _header then
      // TODO: we need to provide a good error handling route for crap
      try
        let payload_size: USize = _handler.payload_length(consume data)

        conn.expect(payload_size)
        _header = false
      end
      true
    else
      let ingest_ts = Time.nanos()
      let pipeline_time_spent: U64 = 0

      ifdef "trace" then
        @printf[I32](("Rcvd msg at " + _pipeline_name + " source\n").cstring())
      end

      (let is_finished, let keep_sending, let last_ts) =
        try
          conn.next_sequence_id()
          let decoded =
            try
              _handler.decode(consume data)
            else
              ifdef debug then
                @printf[I32]("Error decoding message at source\n".cstring())
              end
              error
            end
          ifdef "trace" then
            @printf[I32](("Msg decoded at " + _pipeline_name + " source\n").cstring())
          end
          _runner.run[In](_pipeline_name, pipeline_time_spent, decoded,
            conn, _router, _omni_router,
            conn, _guid_gen.u128(), None, 0, 0, ingest_ts, 1, ingest_ts, _metrics_reporter)
        else
          Fail()
          (true, true, ingest_ts)
        end

      if is_finished then
        let end_ts = Time.nanos()
        let time_spent = end_ts - ingest_ts

        ifdef "detailed-metrics" then
          _metrics_reporter.step_metric(_pipeline_name,
            "Before end at TCP Source", 9999,
            last_ts, end_ts)
        end

        _metrics_reporter.pipeline_metric(_pipeline_name, time_spent + pipeline_time_spent)
        _metrics_reporter.worker_metric(_pipeline_name, time_spent)
      end

      // We have a full queue at a route, so we need to stop reading.
      // if not keep_sending then
      //   conn._mute()
      // end

      conn.expect(_header_size)
      _header = true

      ifdef linux then
        true
      else
        false
      end
    end

  fun ref accepted(conn: TCPSource ref) =>
    @printf[I32]((_source_name + ": accepted a connection\n").cstring())
    conn.expect(_header_size)

  // TODO: implement connect_failed
