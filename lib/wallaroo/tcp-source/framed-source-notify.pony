use "time"
use "sendence/guid"
use "wallaroo/backpressure"
use "wallaroo/messages"
use "wallaroo/metrics"
use "wallaroo/topology"
use "wallaroo/resilience"

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
  let _metrics_reporter: MetricsReporter
  let _header_size: USize
  var _msg_count: USize = 0
  var _outgoing_seq_id: U64 = 0
  var _origin: (Origin tag | None) = None

  new iso create(pipeline_name: String, handler: FramedSourceHandler[In] val,
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso, alfred: Alfred tag)
  =>
    _pipeline_name = pipeline_name
    // TODO: Figure out how to name sources
    _source_name = pipeline_name + " source"
    _handler = handler
    _runner = runner_builder(metrics_reporter.clone(), alfred)
    _router = router
    _metrics_reporter = consume metrics_reporter
    _header_size = _handler.header_length()

  fun routes(): Array[CreditFlowConsumerStep] val =>
    _router.routes()

  fun ref set_origin(origin: Origin tag) =>
    _origin = origin

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
      @printf[I32]("!! RECVD at SOURCE\n".cstring())
      let ingest_ts = Time.nanos()
      let computation_start = Time.nanos()

      let is_finished =
        try
          match _origin
          | let o: Origin tag =>
            _outgoing_seq_id = _outgoing_seq_id + 1
            let decoded = _handler.decode(consume data)
            @printf[I32]("!! Decoded at SOURCE\n".cstring())
            _runner.run[In](_pipeline_name, ingest_ts, decoded,
              conn, _router,
              // incoming envelope (of which technically there is none)
              o, 0, None, 0, 0,
              // outgoing envelope with msg_uid
              o, _guid_gen.u128(), None, 0)
          else
            @printf[I32]("FramedSourceNotify needs an Origin to pass along!\n".cstring())
            true
          end
        else
          // TODO: we need to provide a good error handling route for crap
          true
        end

      let computation_end = Time.nanos()

      _metrics_reporter.step_metric(_source_name,
        computation_start, computation_end)
      if is_finished then
        _metrics_reporter.pipeline_metric(_pipeline_name, ingest_ts)
      end

      conn.expect(_header_size)
      _header = true

      ifdef linux then
        _msg_count = _msg_count + 1
        if ((_msg_count % 25) == 0) then
          false
        else
          true
        end
      else
        false
      end
    end

  fun ref accepted(conn: TCPSource ref) =>
    @printf[I32]((_source_name + ": accepted a connection\n").cstring())
    conn.expect(_header_size)

  // TODO: implement connect_failed
