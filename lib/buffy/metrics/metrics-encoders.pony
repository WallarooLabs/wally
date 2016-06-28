use "collections"
use "json"
use "sendence/bytes"
use "sendence/hub"

interface MetricsCollectionOutputEncoder
  fun encode_sinks(sinks: SinkMetrics, period: U64, app_name: String)
    : ByteSeq
  fun encode_boundaries(boundaries: BoundaryMetrics, period: U64,
    app_name: String): ByteSeq
  fun encode_steps(steps: StepMetrics, period: U64, app_name: String)
    : ByteSeq

class MonitoringHubEncoder is MetricsCollectionOutputEncoder
  let _pretty_print: Bool
  new val create(pretty_print: Bool = true) =>
    _pretty_print = pretty_print

  fun encode_sinks(sinks: SinkMetrics, period: U64, app_name: String)
    : ByteSeq
  =>
    HubJson.payload(MetricsCategories.sinks(), "metrics:" + app_name,
      _json_sinks(sinks, period), _pretty_print)

  fun encode_boundaries(boundaries: BoundaryMetrics, period: U64,
    app_name: String): ByteSeq
  =>
    HubJson.payload(MetricsCategories.boundaries(), "metrics:" + app_name,
      _json_boundaries(boundaries, period), _pretty_print)

  fun encode_steps(steps: StepMetrics, period: U64, app_name: String)
    : ByteSeq
  =>
    HubJson.payload(MetricsCategories.steps(), "metrics:" + app_name,
      _json_steps(steps, period), _pretty_print)

  fun _json_sinks(metrics: SinkMetrics, period: U64): JsonArray ref^ =>
    var j: JsonArray ref^ = JsonArray

    // Iterate through sink metrics and fill them into the array
    for (name, timebucket) in metrics.pairs() do
      for (t_f, (lh, th)) in timebucket.pairs() do
        let j': JsonObject ref = JsonObject
        j'.data.update("category", "source-sink")
        j'.data.update("pipeline_key", name)
        j'.data.update("t1", t_f.i64())
        j'.data.update("t0", (t_f - period).i64())
        let topics: JsonObject ref = JsonObject
        j'.data.update("topics", topics)
        let latencies: JsonObject ref = JsonObject
        let throughputs: JsonObject ref = JsonObject
        topics.data.update("latency_bins", latencies)
        topics.data.update("throughput_out", throughputs)
        for (bin, count) in lh.bin_map().pairs() do
          latencies.data.update(bin.string(), count.i64())
        end
        for (t', count) in th.values().values() do
          throughputs.data.update(t'.string(), count.i64())
        end
        j.data.push(j')
      end
    end

    consume j

  fun _json_boundaries(metrics: BoundaryMetrics, period: U64): JsonArray ref^ =>
    var j: JsonArray ref^ = JsonArray

    // Iterate through sink metrics and fill them into the array
    for (name, timebucket) in metrics.pairs() do
      for (t_f, (lh, th)) in timebucket.pairs() do
        let j': JsonObject ref = JsonObject
        j'.data.update("category", "ingress-egress")
        j'.data.update("pipeline_key", "boundary-" + name)
        j'.data.update("t1", t_f.i64())
        j'.data.update("t0", (t_f - period).i64())
        let topics: JsonObject ref = JsonObject
        j'.data.update("topics", topics)
        let latencies: JsonObject ref = JsonObject
        let throughputs: JsonObject ref = JsonObject
        topics.data.update("latency_bins", latencies)
        topics.data.update("throughput_out", throughputs)
        for (bin, count) in lh.bin_map().pairs() do
          latencies.data.update(bin.string(), count.i64())
        end
        for (t', count) in th.values().values() do
          throughputs.data.update(t'.string(), count.i64())
        end
        j.data.push(j')
      end
    end

    consume j

  fun _json_steps(metrics: StepMetrics, period: U64): JsonArray ref^ =>
    var j: JsonArray ref^ = JsonArray

    // Iterate through sink metrics and fill them into the array
    for (name, timebucket) in metrics.pairs() do
      for (t_f, (lh, th)) in timebucket.pairs() do
        let j': JsonObject ref = JsonObject
        j'.data.update("category", "step")
        j'.data.update("pipeline_key", "step-" + name)
        j'.data.update("t1", t_f.i64())
        j'.data.update("t0", (t_f - period).i64())
        let topics: JsonObject ref = JsonObject
        j'.data.update("topics", topics)
        let latencies: JsonObject ref = JsonObject
        let throughputs: JsonObject ref = JsonObject
        topics.data.update("latency_bins", latencies)
        topics.data.update("throughput_out", throughputs)
        for (bin, count) in lh.bin_map().pairs() do
          latencies.data.update(bin.string(), count.i64())
        end
        for (t', count) in th.values().values() do
          throughputs.data.update(t'.string(), count.i64())
        end
        j.data.push(j')
      end
    end

    consume j
