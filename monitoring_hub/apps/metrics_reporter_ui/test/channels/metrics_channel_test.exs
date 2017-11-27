defmodule MetricsReporterUI.MetricsChannelTest do
  use MetricsReporterUI.ChannelCase
  require Logger

  alias MetricsReporterUI.MetricsChannel

  setup do
    {:ok, _, socket} = socket()
      |> subscribe_and_join(MetricsChannel, "metrics:test")
    timestamp = generate_timestamp()
    start_timestamp = timestamp
    end_timestamp = timestamp + 1

    pipeline_key = "NODE1"

    latency_bins = %{
      "0.0001" => 500,
      "0.001" => 250,
      "0.01" => 250
    }

    string_start_timestamp = Integer.to_string round(start_timestamp)
    string_end_timestamp = Integer.to_string round(end_timestamp)

    throughput_data = %{
      string_start_timestamp => 500,
      string_end_timestamp => 500
    }

    throughput_msg = cerate_throughput_msg(round(start_timestamp), pipeline_key, 500)
    latency_bins_msg = create_latency_bins_msg(round(end_timestamp), pipeline_key, latency_bins)

    metrics = %{
      "pipeline_key" => pipeline_key,
      "t0" => start_timestamp,
      "t1" => end_timestamp,
      "topics" => %{
        "latency_bins" => latency_bins,
        "throughput_out" => throughput_data
      }
    }

    step_metrics = Map.put(metrics, "category", "step")
    source_sink_metrics = Map.put(metrics, "category", "source-sink")
    ingress_egress_metrics = Map.put(metrics, "category", "ingress-egress")

    {:ok, socket: socket, step_metrics: step_metrics,
      throughput_msg: throughput_msg, latency_bins_msg: latency_bins_msg,
      source_sink_metrics: source_sink_metrics, ingress_egress_metrics: ingress_egress_metrics}
  end

  defp generate_timestamp do
    {mega_seconds, seconds, milliseconds} = :erlang.timestamp
    (mega_seconds * 1000000) + seconds + (milliseconds * 0.000001)
  end

  defp cerate_throughput_msg(timestamp, pipeline_key, throughput) do
    %{"time" => timestamp, "pipeline_key" => pipeline_key, "total_throughput" => throughput}
  end

  defp create_latency_bins_msg(timestamp, pipeline_key, latency_bins) do
    %{"time" => timestamp, "pipeline_key" => pipeline_key, "latency_bins" => latency_bins}
  end
end
