use "collections"
use "json"
use "sendence/bytes"

primitive SinkMetricsEncoder
  fun apply(sinkmetrics: SinkMetrics, period: U64): Array[U8] iso^ =>
    var d: Array[U8] iso = recover Array[U8] end
    // construct the json objects
    var j: JsonArray ref = JsonArray

    // Iterate through sink metrics and fill them into the array
    for (name, timebucket) in sinkmetrics.pairs() do
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

    // Convert the string to bytes and push to d
    d.append(j.string())
    consume d
