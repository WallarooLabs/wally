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

use "buffered"
use "collections"
use "files"
use "format"
use "net"
use "wallaroo_labs/hub"
use "wallaroo_labs/options"
use "wallaroo_labs/time"

actor Main
  new create(env: Env) =>
    let options = Options(env.args)
    var input_file_path: String = ""
    var output_file_path: String = ""


    options
      .add("input", "i", StringArgument)
      .add("output", "o", StringArgument)
      .add("help", "h", None)

    for option in options do
      match option
      | ("input", let arg: String) => input_file_path = arg
      | ("output", let arg: String) => output_file_path = arg
      | ("help", None) =>
        @printf[I32](
        """
        --input/-i <file path> [Input file path where metrics are stored]
        --output/-o <file path> [Output file path where report will be written]
        """)
        return
      | let err: ParseError =>
        err.report(env.err)
      end
    end
    if (input_file_path == "") or (output_file_path == "") then
        @printf[I32](
        """
        --input/-i <file path> [Input file path where metrics are stored]
        --output/-o <file path> [Output file path where report will be written]
        """
        )
        return
    else
      MetricsCollector(env, input_file_path, output_file_path)
    end

actor MetricsCollector
  let _env: Env
  let _input_file_path: String
  let _output_file_path: String
  let _overall_metrics_msgs: Map[String, Array[HubMetricsMsg]] =
    _overall_metrics_msgs.create()
  let _computation_metrics_msgs: Map[String, Array[HubMetricsMsg]] =
    _computation_metrics_msgs.create()
  let _worker_metrics_msgs: Map[String, Array[HubMetricsMsg]] =
    _worker_metrics_msgs.create()
  let _overall_metrics_data: Map[String, MetricsData] =
    _overall_metrics_data.create()
  let _computation_metrics_data: Map[String, MetricsData] =
    _computation_metrics_data.create()
  let _worker_metrics_data: Map[String, MetricsData] =
    _worker_metrics_data.create()

  new create(env: Env, input_file_path: String, output_file_path: String) =>
    _env = env
    _input_file_path = input_file_path
    _output_file_path = output_file_path
    collect_metrics()

  fun ref add_metrics(metrics_msg: HubMetricsMsg) =>
    match metrics_msg.category
    | ("start-to-end") =>
      add_overall_metrics(metrics_msg)
    | ("computation") =>
      add_computation_metrics(metrics_msg)
    | ("node-ingress-egress") =>
      add_worker_metrics(metrics_msg)
    else
      @printf[I32](("Unable to save metrics for category: " +
        metrics_msg.category + "\n").cstring())
    end

  fun ref add_overall_metrics(metrics_msg: HubMetricsMsg) =>
    let name = metrics_msg.name
    let metrics_array = _overall_metrics_msgs.get_or_else(name,
      Array[HubMetricsMsg])
    metrics_array.push(metrics_msg)
    _overall_metrics_msgs.update(name, metrics_array)

  fun ref add_computation_metrics(metrics_msg: HubMetricsMsg) =>
    let name = metrics_msg.name
    let metrics_array = _computation_metrics_msgs.get_or_else(name,
      Array[HubMetricsMsg])
    metrics_array.push(metrics_msg)
    _computation_metrics_msgs.update(name, metrics_array)

  fun ref add_worker_metrics(metrics_msg: HubMetricsMsg) =>
    let name = metrics_msg.name
    let metrics_array = _worker_metrics_msgs.get_or_else(name,
      Array[HubMetricsMsg])
    metrics_array.push(metrics_msg)
    _worker_metrics_msgs.update(name, metrics_array)

  be print_metrics() =>
    try
      let auth = _env.root as AmbientAuth
      let output_file = File(FilePath(auth, _output_file_path)?)
      output_file.write(TextFormatter.main_header())
      output_file.write(TextFormatter.main_header())
      output_file.print("Wallaroo Metrics Report")
      output_file.write(TextFormatter.main_header())
      output_file.write(TextFormatter.main_header())
      output_file.write(TextFormatter.line_break())
      output_file.print("Metrics sourced from file: " + _input_file_path)
      output_file.write(TextFormatter.line_break())
      output_file.write(TextFormatter.main_header())
      output_file.write("Overall(Source -> Sink) Metrics\n")
      output_file.write(TextFormatter.main_header())
      for metrics_data in _overall_metrics_data.values() do
        output_file.write(metrics_data.print_stats())
      end
      output_file.write(TextFormatter.line_break())
      output_file.write(TextFormatter.main_header())
      output_file.write("Worker Metrics\n")
      output_file.write(TextFormatter.main_header())
      for metrics_data in _worker_metrics_data.values() do
        output_file.write(metrics_data.print_stats())
      end
      output_file.write(TextFormatter.line_break())
      output_file.write(TextFormatter.main_header())
      output_file.write("Computation Metrics\n")
      output_file.write(TextFormatter.main_header())
      for metrics_data in _computation_metrics_data.values() do
        output_file.write(metrics_data.print_stats())
      end
      output_file.write(TextFormatter.line_break())
      let print_timestamp = WallClock.milliseconds()
      output_file.print("Report generated at: " + print_timestamp.string())
      output_file.dispose()
      @printf[I32]("Output file disposed\n".cstring())
    end

  be collect_metrics() =>
     @printf[I32]("Collecting Metrics\n".cstring())
    try
      let auth = _env.root as AmbientAuth

      let input_file = File(FilePath(auth, _input_file_path)?)
      let input: Array[U8] val = input_file.read(input_file.size())

      let rb = Reader
      rb.append(input)
      var bytes_left = input.size()

      while bytes_left > 0 do
        let next_payload_size = rb.u32_be()?.usize()
        try
          let hub_msg = HubProtocolDecoder(rb.block(next_payload_size)?)?
          match hub_msg
          | HubJoinMsg =>
            @printf[I32]("Decoded HubJoinMsg\n".cstring())
          | HubConnectMsg =>
            @printf[I32]("Decoded HubConnectMsg\n".cstring())
          | HubOtherMsg =>
            @printf[I32]("Decoded HubOtherMsg\n".cstring())
          else
            add_metrics(hub_msg as HubMetricsMsg)
          end

        else
          @printf[I32]("Problem decoding!\n".cstring())
        end
        bytes_left = bytes_left - (next_payload_size + 4)
      end
      input_file.dispose()
      @printf[I32]("Input file disposed\n".cstring())
    end
    generate_overall_metrics_data()
    generate_computation_metrics_data()
    generate_worker_metrics_data()
    print_metrics()

  fun ref generate_metrics_data() =>
    @printf[I32]("Generate Metrics Data\n".cstring())
    generate_overall_metrics_data()
    generate_computation_metrics_data()
    generate_worker_metrics_data()

  fun ref generate_overall_metrics_data() =>
   for (name, metrics_msgs) in _overall_metrics_msgs.pairs() do
    try
      let metrics_msg = metrics_msgs(0)?
      let metrics_data = MetricsData(metrics_msg.name, metrics_msg.category,
        metrics_msg.period, metrics_msgs)
      _overall_metrics_data.insert(name, metrics_data)?
    end
   end

  fun ref generate_computation_metrics_data() =>
    for (name, metrics_msgs) in _computation_metrics_msgs.pairs() do
    try
       let metrics_msg = metrics_msgs(0)?
       let metrics_data = MetricsData(metrics_msg.name, metrics_msg.category,
         metrics_msg.period, metrics_msgs)
       _computation_metrics_data.insert(name, metrics_data)?
     end
    end

  fun ref generate_worker_metrics_data() =>
    for (name, metrics_msgs) in _worker_metrics_msgs.pairs() do
    try
       let metrics_msg = metrics_msgs(0)?
       let metrics_data = MetricsData(metrics_msg.name, metrics_msg.category,
         metrics_msg.period, metrics_msgs)
       _worker_metrics_data.insert(name, metrics_data)?
     end
    end

class MetricsData
  var name: String
  var category: String
  var min_period_ends_at: U64 = U64.max_value()
  var max_period_ends_at: U64 = U64.min_value()
  var period: U64
  var overall_min: U64 = U64.max_value()
  var overall_max: U64 = U64.min_value()
  var min_throughput_by_period: U64 = U64.max_value()
  var max_throughput_by_period: U64 = U64.min_value()
  var throughputs_by_period: Map[U64, U64] = throughputs_by_period.create()
  var total_throughput: U64 = 0
  var total_counts_per_bin: Array[U64] = Array[U64].init(0,65)
  var throughput_stats: ( ThroughputStats | None ) = None
  var latency_stats: ( LatencyStats | None ) = None

  new create(name': String, category': String, period': U64,
    metrics_msgs: Array[HubMetricsMsg])
  =>
    name = name'
    category = category'
    period = period'
    try
      for metrics_msg in metrics_msgs.values() do
        update_total_counts_per_bin(metrics_msg.histogram)?
        update_min(metrics_msg.histogram_min)
        update_max(metrics_msg.histogram_max)
        update_min_period_ends_at(metrics_msg.period_ends_at)
        update_max_period_ends_at(metrics_msg.period_ends_at)
        let throughput_for_period =
          calculate_throughput_for_period(metrics_msg.histogram)
        update_throughput_by_period_end(throughput_for_period, metrics_msg.period_ends_at)?
      end
    end
    calculate_total_throughput()
    calculate_throughput_min_max()
    generate_throughput_stats()
    generate_latency_stats()

  fun ref calculate_throughput_for_period(count_by_bin:
    Array[U64 val] val): U64
  =>
    var total_throughput_for_period: U64 = 0
    for count in count_by_bin.values() do
      total_throughput_for_period = total_throughput_for_period + count
    end
    total_throughput_for_period

  fun ref update_total_counts_per_bin(counts_by_bin: Array[U64 val] val) ? =>
    for idx in Range(0, 65) do
      let count_in_bin = counts_by_bin(idx)?
      if count_in_bin != 0 then
        let total_count_in_bin = total_counts_per_bin(idx)?
        let updated_count_in_bin = total_count_in_bin + count_in_bin
        total_counts_per_bin.update(idx, updated_count_in_bin)?
      end
    end

  fun ref update_min(min: U64) =>
    if min < overall_min then
      overall_min = min
    end

  fun ref update_max(max: U64) =>
    if max > overall_max then
      overall_max = max
    end

  fun ref update_min_period_ends_at(period_ends_at: U64) =>
    if period_ends_at < min_period_ends_at then
      min_period_ends_at = period_ends_at
    end

  fun ref update_max_period_ends_at(period_ends_at: U64) =>
    if period_ends_at > max_period_ends_at then
      max_period_ends_at = period_ends_at
    end

  fun ref update_throughput_by_period_end(throughput: U64,
    period_end: U64) ?
  =>
    throughputs_by_period.upsert(period_end, throughput,
      {(prev_throughput: U64, current_throughput: U64): U64 =>
        prev_throughput + current_throughput
      })?

  fun ref calculate_throughput_min_max() =>
    for (period_end, throughput) in throughputs_by_period.pairs() do
      update_min_throughput_by_period(throughput)
      update_max_throughput_by_period(throughput)
    end

  fun ref update_min_throughput_by_period(throughput: U64) =>
    if throughput < min_throughput_by_period then
      min_throughput_by_period = throughput
    end

  fun ref update_max_throughput_by_period(throughput: U64) =>
    if throughput > max_throughput_by_period then
      max_throughput_by_period = throughput
    end

  fun ref calculate_total_throughput() =>
    for count_at_bin in total_counts_per_bin.values() do
      total_throughput = total_throughput + count_at_bin
    end

  fun ref generate_throughput_stats() =>
    throughput_stats = ThroughputStats(this)

  fun ref generate_latency_stats() =>
    latency_stats = LatencyStats(this)

  fun ref print_stats(): String iso^ =>
    let header = (TextFormatter.secondary_header()).clone()
      .>append("Stats for: ")
      .>append(name)
      .>append(TextFormatter.line_break())
      .>append(TextFormatter.secondary_header())
      .>append("Initial metric timestamp: ")
      .>append(min_period_ends_at.string())
      .>append(TextFormatter.line_break())
      .>append("Final metric timestamp:   ")
      .>append(max_period_ends_at.string())
      .>append(TextFormatter.line_break())
      .>append(TextFormatter.line_break())


    let throughput_stats_text = if throughput_stats is None then
      "No Throughput Stats to report.\n"
    else
      throughput_stats.string()
    end

    let latency_stats_text = if latency_stats is None then
      "No Latency Stats to report.\n"
    else
      latency_stats.string()
    end

    header.>append(throughput_stats_text)
      .>append(latency_stats_text).clone()


class ThroughputStats
  var _total_throughput: U64
  var _period: U64
  var _min_period_ends_at: U64
  var _max_period_ends_at: U64
  var avg_throughput_per_sec: F64 = 0
  var min_throughput_per_sec: F64 = 0
  var max_throughput_per_sec: F64 = 0
  var min_throughput_by_period: U64 = 0
  var max_throughput_by_period: U64 = 0
  var _trunc_period: U64

  new create(metrics_data: MetricsData)
  =>
    _total_throughput = metrics_data.total_throughput
    _period = metrics_data.period
    _min_period_ends_at = metrics_data.min_period_ends_at
    _max_period_ends_at = metrics_data.max_period_ends_at
    min_throughput_by_period = metrics_data.min_throughput_by_period
    max_throughput_by_period = metrics_data.max_throughput_by_period
    _trunc_period = _period / 1000000000
    calculate_throughput_per_sec()
    calculate_min_throughput_per_sec()
    calculate_max_throughput_per_sec()

  fun ref calculate_throughput_per_sec() =>
    let periods_count =
      ((_max_period_ends_at - _min_period_ends_at) + _period) / _period
    let throughput_per_period = _total_throughput.f64() / periods_count.f64()
    let trunc_period = _period / 1000000000
    avg_throughput_per_sec = throughput_per_period / trunc_period.f64()

  fun ref calculate_min_throughput_per_sec() =>
    min_throughput_per_sec =
      min_throughput_by_period.f64() / _trunc_period.f64()

  fun ref calculate_max_throughput_per_sec() =>
    max_throughput_per_sec =
      max_throughput_by_period.f64() / _trunc_period.f64()

  fun format_throughput(throughput: F64): String iso^ =>
    let divided_throughput = throughput / 1000.0
    let formatted_throughput =
      if divided_throughput >= 10.0 then
        divided_throughput.u64().string()
      elseif divided_throughput >= 1.0 then
        Format.float[F64](where x = divided_throughput, prec = 3)
      elseif divided_throughput >= 0.1 then
        Format.float[F64](where x = divided_throughput, prec = 2)
      elseif divided_throughput >= 0.01 then
        Format.float[F64](where x = divided_throughput, prec = 1)
      elseif throughput == 0.0 then
        return "0".clone()
      else
        return "Under 100".clone()
      end
    formatted_throughput.clone().>append("k").clone()

  fun string(): String iso^ =>
    (TextFormatter.secondary_header()).clone()
      .>append("Throughput Stats\n")
      .>append(TextFormatter.secondary_header())
      .>append("Minimum Throughput per sec: ")
      .>append(format_throughput(min_throughput_per_sec))
      .>append(TextFormatter.line_break())
      .>append("Average Throughput per sec: ")
      .>append(format_throughput(avg_throughput_per_sec))
      .>append(TextFormatter.line_break())
      .>append("Maximum Throughput per sec: ")
      .>append(format_throughput(max_throughput_per_sec))
      .>append(TextFormatter.line_break())
      .>append(TextFormatter.line_break())
      .clone()

class LatencyStats
  var _bin_at_50_percent: U64 = 0
  var _bin_at_75_percent: U64 = 0
  var _bin_at_90_percent: U64 = 0
  var _bin_at_95_percent: U64 = 0
  var _bin_at_99_percent: U64 = 0
  var _bin_at_99_9_percent: U64 = 0
  var _bin_at_99_99_percent: U64 = 0
  var _counts_per_bin: Array[U64]
  var _cumalative_counts_per_bin: Array[U64] = Array[U64]
  var _percentage_at_bins: Array[F64] = Array[F64]
  var _total_count: U64
  var _bin_to_time_converter: BinToTimeConverter = BinToTimeConverter

  new create(metrics_data: MetricsData) =>
    _total_count = metrics_data.total_throughput
    _counts_per_bin = metrics_data.total_counts_per_bin
    calculate_cumulative_counts_per_bin()
    calculate_percentage_at_bins()
    calculate_bin_at_percents()

  fun ref calculate_cumulative_counts_per_bin() =>
    var cumalative_count: U64 = 0
    for count_at_bin in _counts_per_bin.values() do
      cumalative_count = cumalative_count + count_at_bin
      _cumalative_counts_per_bin.push(cumalative_count)
    end

  fun ref calculate_percentage_at_bins() =>
    for cumulative_count_in_bin in _cumalative_counts_per_bin.values() do
      let percentage_at_bin = calculate_percentage(cumulative_count_in_bin)
      _percentage_at_bins.push(percentage_at_bin)
    end

  fun ref calculate_percentage(cumulative_count_in_bin: U64): F64 =>
    if _total_count == 0 then
      0.0
    else
      (cumulative_count_in_bin.f64() / _total_count.f64()) * 100.0
    end

  fun ref calculate_bin_at_percents() =>
    calculate_bin_at_percent(50.0)
    calculate_bin_at_percent(75.0)
    calculate_bin_at_percent(90.0)
    calculate_bin_at_percent(95.0)
    calculate_bin_at_percent(99.0)
    calculate_bin_at_percent(99.9)
    calculate_bin_at_percent(99.99)

  fun ref calculate_bin_at_percent(percent: F64) =>
    var bin_at_percent: U64 = 0
    for (idx, percent_at_bin) in _percentage_at_bins.pairs() do
      if percent_at_bin >= percent then
        bin_at_percent = idx.u64()
        break
      end
    end
    if bin_at_percent != 0 then
      match percent
      | (50.0) =>
        _bin_at_50_percent = bin_at_percent
      | (75.0) =>
        _bin_at_75_percent = bin_at_percent
      | (90.0) =>
        _bin_at_90_percent = bin_at_percent
      | (95.0) =>
        _bin_at_95_percent = bin_at_percent
      | (99.0) =>
        _bin_at_99_percent = bin_at_percent
      | (99.9) =>
        _bin_at_99_9_percent = bin_at_percent
      | (99.99) =>
        _bin_at_99_99_percent = bin_at_percent
      end
    end

  fun string(): String iso^ =>
    (TextFormatter.secondary_header()).clone()
      .>append("Latency Stats\n")
      .>append(TextFormatter.secondary_header())
      .>append("   50% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_50_percent))
      .>append(TextFormatter.line_break())
      .>append("   75% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_75_percent))
      .>append(TextFormatter.line_break())
      .>append("   90% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_90_percent))
      .>append(TextFormatter.line_break())
      .>append("   95% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_95_percent))
      .>append(TextFormatter.line_break())
      .>append("   99% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_99_percent))
      .>append(TextFormatter.line_break())
      .>append(" 99.9% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_99_9_percent))
      .>append(TextFormatter.line_break())
      .>append("99.99% of latencies are: ")
      .>append(_bin_to_time_converter.get_time_for_bin(_bin_at_99_99_percent))
      .>append(TextFormatter.line_break())
      .>append(TextFormatter.line_break())
      .clone()

  primitive TextFormatter
    fun main_header(): String =>
      "****************************************\n"

    fun secondary_header(): String =>
      "------------------------\n"

    fun line_break(): String =>
      "\n"

  class BinToTimeConverter
  let _power_to_time_map: Map[F32, String] = Map[F32, String](32)
  let _base: F32 = 2

  new create() =>
    try
      _power_to_time_map.insert(0, "Unable to determine the latency bin")?
      _power_to_time_map.insert(1, "≤   1 ns")?
      _power_to_time_map.insert(2, "≤   2 ns")?
      _power_to_time_map.insert(4, "≤   4 ns")?
      _power_to_time_map.insert(8, "≤   8 ns")?
      _power_to_time_map.insert(16, "≤  16 ns")?
      _power_to_time_map.insert(32, "≤  32 ns")?
      _power_to_time_map.insert(64, "≤  64 ns")?
      _power_to_time_map.insert(128, "≤ 128 ns")?
      _power_to_time_map.insert(256, "≤ 256 ns")?
      _power_to_time_map.insert(512, "≤ 512 ns")?
      _power_to_time_map.insert(1_024, "≤   1 μs")?
      _power_to_time_map.insert(2_048, "≤   2 μs")?
      _power_to_time_map.insert(4_096, "≤   4 μs")?
      _power_to_time_map.insert(8_192, "≤   8 μs")?
      _power_to_time_map.insert(16_384, "≤  16 μs")?
      _power_to_time_map.insert(32_768, "≤  32 μs")?
      _power_to_time_map.insert(65_536, "≤  66 μs")?
      _power_to_time_map.insert(131_072, "≤ 130 μs")?
      _power_to_time_map.insert(262_144, "≤ 260 μs")?
      _power_to_time_map.insert(524_288, "≤ 0.5 ms")?
      _power_to_time_map.insert(1_048_576, "≤   1 ms")?
      _power_to_time_map.insert(2_097_152, "≤   2 ms")?
      _power_to_time_map.insert(4_194_304, "≤   4 ms")?
      _power_to_time_map.insert(8_388_608, "≤   8 ms")?
      _power_to_time_map.insert(16_777_216, "≤  16 ms")?
      _power_to_time_map.insert(33_554_432, "≤  34 ms")?
      _power_to_time_map.insert(67_108_864, "≤  66 ms")?
      _power_to_time_map.insert(134_217_728, "≤ 134 ms")?
      _power_to_time_map.insert(268_435_456, "≤ 260 ms")?
      _power_to_time_map.insert(536_870_912, "≤ 0.5 s")?
      _power_to_time_map.insert(1_073_741_824, "≤   1 s")?
    end

  fun get_time_for_bin(bin: U64): String =>
    let power = _base.pow(bin.f32())
    _power_to_time_map.get_or_else(power, "> 1 s")
