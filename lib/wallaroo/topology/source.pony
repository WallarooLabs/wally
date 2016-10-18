use "net"
use "time"
use "buffered"
use "collections"
use "wallaroo/metrics"
use "wallaroo/messages"

interface BytesProcessor
  fun ref process(data: Array[U8 val] iso)

class Source[In: Any val] is Origin
  let _decoder: SourceDecoder[In] val
  let _pipeline_name: String
  let _source_name: String
  let _runner: Runner
  let _router: Router val
  let _metrics_reporter: MetricsReporter
  let _outgoing_envelope: MsgEnvelope ref
  var _count: USize = 0

  new iso create(pipeline_name: String, decoder: SourceDecoder[In] val, 
    runner_builder: RunnerBuilder val, router: Router val,
    metrics_reporter: MetricsReporter iso) 
  =>
    _decoder = decoder
    _pipeline_name = pipeline_name
    _source_name = pipeline_name + " source"
    _metrics_reporter = consume metrics_reporter
    _runner = runner_builder(_metrics_reporter.clone())
    _outgoing_envelope = MsgEnvelope(this, 0, None, 0, 0)
    _router = router

  // be update_watermark(route_id: U64, seq_id: U64)
  // =>
  //   //TODO: receive watermark, flush buffers and ack upstream (maybe?)
  //   None

  fun ref process(data: Array[U8 val] iso) =>
    let ingest_ts = Time.nanos()
    let computation_start = Time.nanos()
    let is_finished = 
      try
        match _decoder(consume data)
        | let input: In =>
          _outgoing_envelope.msg_uid = _count.u64()
          _outgoing_envelope.seq_id = _count.u64()
          //TODO: incoming envelope?
          let incoming_envelope = _outgoing_envelope.clone()
          _runner.run[In](_pipeline_name, ingest_ts, input, _outgoing_envelope,
          incoming_envelope, _router)
        else
          true
        end
      else
        true
      end

    let computation_end = Time.nanos()

    //_metrics_reporter.step_metric(_source_name,
    //  computation_start, computation_end)
    if is_finished then
      _metrics_reporter.pipeline_metric(_pipeline_name, ingest_ts)
    end
