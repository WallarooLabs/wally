defmodule MetricsReporterUI.MetricsChannel do
	use Phoenix.Channel
  require Logger

  alias MonitoringHubUtils.MessageLog
  alias MetricsReporterUI.{AppConfigBroadcaster, ThroughputsBroadcaster, ThroughputStatsBroadcaster, LatencyStatsBroadcaster}

  def join("metrics:" <> app_name, _message, socket) do
    _response = AppConfigBroadcaster.start_link app_name
    {:ok, socket}
  end

  def handle_in("metrics", metrics_collection, socket) do
    "metrics:" <> app_name = socket.topic
    Enum.each(metrics_collection, fn (%{"pipeline_key" => pipeline_key,
      "t0" => _start_timestamp, "t1" => end_timestamp,
      "category" => category,
      "topics" => %{"latency_bins" => latency_bins,
      "throughput_out" => throughput_data}}) ->
      int_end_timestamp = float_timestamp_to_int(end_timestamp)
      latency_bins_msg = create_latency_bins_msg(pipeline_key, int_end_timestamp, latency_bins)
      store_latency_bins_msg(app_name, category, pipeline_key, latency_bins_msg)
      {:ok, _pid} = find_or_start_latency_bins_worker(app_name, category, pipeline_key)
      store_throughput_msgs(app_name, category, pipeline_key, throughput_data)
      {:ok, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_key)
    end)
    {:reply, :ok, socket}
  end

  def handle_in("step-metrics", metrics_collection, socket) do
    "metrics:" <> app_name = socket.topic
    Enum.each(metrics_collection, fn (%{"pipeline_key" => pipeline_key,
      "t0" => _start_timestamp, "t1" => end_timestamp,
      "category" => "step" = category,
      "topics" => %{"latency_bins" => latency_bins, 
      "throughput_out" => throughput_data}}) ->
      int_end_timestamp = float_timestamp_to_int(end_timestamp)
      latency_bins_msg = create_latency_bins_msg(pipeline_key, int_end_timestamp, latency_bins)
      store_latency_bins_msg(app_name, category, pipeline_key, latency_bins_msg)
      {:ok, _pid} = find_or_start_latency_bins_worker(app_name, category, pipeline_key)
      store_throughput_msgs(app_name, category, pipeline_key, throughput_data)
      {:ok, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_key)
    end)
    {:reply, :ok, socket}  
  end

  def handle_in("ingress-egress-metrics", metrics_collection, socket) do
    "metrics:" <> app_name = socket.topic
    Enum.each(metrics_collection, fn (%{"pipeline_key" => pipeline_key,
      "t0" => _start_timestamp, "t1" => end_timestamp,
      "category" => "ingress-egress" = category,
      "topics" => %{"latency_bins" => latency_bins, 
      "throughput_out" => throughput_data}}) ->
      int_end_timestamp = float_timestamp_to_int(end_timestamp)
      latency_bins_msg = create_latency_bins_msg(pipeline_key, int_end_timestamp, latency_bins)
      store_latency_bins_msg(app_name, category, pipeline_key, latency_bins_msg)
      {:ok, _pid} = find_or_start_latency_bins_worker(app_name, category, pipeline_key)
      store_throughput_msgs(app_name, category, pipeline_key, throughput_data)
      {:ok, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_key)
    end)
    {:reply, :ok, socket}  
  end

  def handle_in("source-sink-metrics", metrics_collection, socket) do
    "metrics:" <> app_name = socket.topic
    Enum.each(metrics_collection, fn (%{"pipeline_key" => pipeline_key,
      "t0" => _start_timestamp, "t1" => end_timestamp,
      "category" => "source-sink" = category,
      "topics" => %{"latency_bins" => latency_bins, 
      "throughput_out" => throughput_data}}) ->
      int_end_timestamp = float_timestamp_to_int(end_timestamp)
      latency_bins_msg = create_latency_bins_msg(pipeline_key, int_end_timestamp, latency_bins)
      store_latency_bins_msg(app_name, category, pipeline_key, latency_bins_msg)
      {:ok, _pid} = find_or_start_latency_bins_worker(app_name, category, pipeline_key)
      store_throughput_msgs(app_name, category, pipeline_key, throughput_data)
      {:ok, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_key)
    end)
    {:reply, :ok, socket}  
  end

  defp float_timestamp_to_int(timestamp) do
    round(timestamp)
  end

  defp create_latency_bins_msg(pipeline_key, timestamp, latency_bins) do
    %{"time" => timestamp, "pipeline_key" => pipeline_key, "latency_bins" => latency_bins}
  end

  defp store_latency_bins_msg(app_name, category, pipeline_key, latency_bins_msg) do
    log_name = generate_latency_bins_log_name(app_name, category, pipeline_key)
    :ok = MessageLog.Supervisor.lookup_or_create(log_name)
    MessageLog.log_message(log_name, latency_bins_msg)
  end

  defp store_throughput_msgs(app_name, category, pipeline_key, throughput_data) do
    timestamps = Map.keys(throughput_data)
    Enum.each(timestamps, fn timestamp ->
      int_timestamp = String.to_integer timestamp
      throughput = throughput_data[timestamp]
      throughput_msg = create_throughput_msg(int_timestamp, pipeline_key, throughput)
      store_throughput_msg(app_name, category, pipeline_key, throughput_msg)
    end)
  end

  defp create_throughput_msg(timestamp, pipeline_key, throughput) do
    %{"time" => timestamp, "pipeline_key" => pipeline_key, "total_throughput" => throughput}
  end

  defp store_throughput_msg(app_name, category, pipeline_key, throughput_msg) do
    log_name = generate_throughput_log_name(app_name, category, pipeline_key)
    :ok = MessageLog.Supervisor.lookup_or_create log_name
    MessageLog.log_throughput_message(log_name, throughput_msg)
  end

  defp generate_throughput_log_name(app_name, category, pipeline_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::throughput:" <> pipeline_key
  end

  defp generate_latency_bins_log_name(app_name, category, pipeline_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::latency-bins:" <> pipeline_key
  end

  defp find_or_start_throughput_workers(app_name, category, pipeline_key) do
    log_name = generate_throughput_log_name(app_name, category, pipeline_key)
    total_throughput_args = [log_name: log_name, interval_key: "last-1-sec", pipeline_key: pipeline_key, app_name: app_name, category: category]
    ThroughputsBroadcaster.Supervisor.find_or_start_worker(total_throughput_args)
    throughput_stats_args = [log_name: log_name, interval_key: "last-5-mins", pipeline_key: pipeline_key, app_name: app_name, category: category, stats_interval: 300]
    ThroughputStatsBroadcaster.Supervisor.find_or_start_worker(throughput_stats_args)
  end

  defp find_or_start_latency_bins_worker(app_name, category, pipeline_key) do
    log_name = generate_latency_bins_log_name(app_name, category, pipeline_key)
    args = [log_name: log_name, interval_key: "last-5-mins",  pipeline_key: pipeline_key, 
      aggregate_interval: 300, app_name: app_name, category: category]
    LatencyStatsBroadcaster.Supervisor.find_or_start_worker(args)
  end
end