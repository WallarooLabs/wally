use "collections"
use "json"
use "sendence/bytes"

interface MetricsCollectionOutputEncoder
  fun encode(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64): Array[U8] iso^
  fun encode_sinks(sinks: SinkMetrics, period: U64): Array[U8] iso^
  fun encode_boundaries(boundaries: BoundaryMetrics, period: U64): Array[U8] 
    iso^
  fun encode_steps(steps: StepMetrics, period: U64): Array[U8] iso^

primitive MonitoringHubEncoder is MetricsCollectionOutputEncoder
  fun encode(sinks: SinkMetrics, boundaries: BoundaryMetrics,
             steps: StepMetrics, period: U64): Array[U8] iso^ =>
      let d: Array[U8] iso = recover Array[U8] end
      let j: JsonArray ref = JsonArray
      j.data.push(_json_sinks(sinks, period))
      j.data.push(_json_boundaries(boundaries, period))
      j.data.push(_json_steps(steps, period))
      d.append(j.string())
      consume d

  fun encode_sinks(sinks: SinkMetrics, period: U64): Array[U8] iso^ =>
    let d: Array[U8] iso = recover Array[U8] end
    d.append(_json_sinks(sinks, period).string())
    consume d

  fun encode_boundaries(boundaries: BoundaryMetrics, period: U64): Array[U8]
    iso^ =>
    let d: Array[U8] iso = recover Array[U8] end
    d.append(_json_boundaries(boundaries, period).string())
    consume d

  fun encode_steps(steps: StepMetrics, period: U64): Array[U8] iso^ =>
    let d: Array[U8] iso = recover Array[U8] end
    d.append(_json_steps(steps, period).string())
    consume d

  fun _json_sinks(metrics: SinkMetrics, period: U64): JsonArray ref^ =>
    var j: JsonArray ref^ = JsonArray

    // Iterate through sink metrics and fill them into the array
    for (name, timebucket) in metrics.pairs() do
      for (t_f, (lh, th)) in timebucket.pairs() do
        let j': JsonObject ref = JsonObject
        j'.data.update("category", "source-sink")
        j'.data.update("pipeline_key", "sink-" + name)
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
        j'.data.update("pipeline_key", "step-" + name.string())
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
