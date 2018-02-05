defmodule MetricsReporterUI.MetricsChannel do
	use Phoenix.Channel
  require Logger

  alias MonitoringHubUtils.MessageLog
  alias MonitoringHubUtils.Stores.AppConfigStore
  alias MetricsReporterUI.{AppConfigBroadcaster, ThroughputsBroadcaster, ThroughputStatsBroadcaster, LatencyStatsBroadcaster}

  def join("metrics:" <> app_name, join_message, socket) do
    %{"worker_name" => worker_name} = join_message
    _response = AppConfigBroadcaster.start_link app_name
    {:ok, _response} = AppConfigStore.add_worker_to_app_config(app_name, worker_name)
    {:ok, socket}
  end

  def handle_in("metrics", %{"category" => "start-to-end"} = metrics_msg, socket) do
    "metrics:" <> app_name = socket.topic
    %{"category" => category, "latency_list" => latency_list,
      "timestamp" => end_timestamp, "period" => period, "name" => pipeline_key,
      "min" => _min, "max" => _max} = metrics_msg
    [pipeline_name, _worker_name] = String.split(pipeline_key, "@")
    # By worker
    latency_list_msg = create_latency_list_msg(pipeline_key, end_timestamp, latency_list)
    store_latency_list_msg(app_name, "start-to-end-by-worker", pipeline_key, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(pipeline_key, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, "start-to-end-by-worker", pipeline_key, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, "start-to-end-by-worker", pipeline_key, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, "start-to-end-by-worker", pipeline_key, msg_timestamp)
    # By Pipeline
    latency_list_msg = create_latency_list_msg(pipeline_name, end_timestamp, latency_list)
    store_latency_list_msg(app_name, category, pipeline_name, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(pipeline_name, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, category, pipeline_name, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, category, pipeline_name, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_name, msg_timestamp)
    {:noreply, socket}
  end

  def handle_in("metrics", %{"category" => "node-ingress-egress"} = metrics_msg, socket) do
    "metrics:" <> app_name = socket.topic
    %{"category" => category, "latency_list" => latency_list,
      "timestamp" => end_timestamp, "period" => period, "name" => pipeline_key,
      "min" => _min, "max" => _max} = metrics_msg
    # By Pipeline
    latency_list_msg = create_latency_list_msg(pipeline_key, end_timestamp, latency_list)
    store_latency_list_msg(app_name, "node-ingress-egress-by-pipeline", pipeline_key, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(pipeline_key, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, "node-ingress-egress-by-pipeline", pipeline_key, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, "node-ingress-egress-by-pipeline", pipeline_key, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, "node-ingress-egress-by-pipeline", pipeline_key, msg_timestamp)
    # By Worker
    [_pipeline_name, worker_name] = String.split(pipeline_key, "*")
    latency_list_msg = create_latency_list_msg(worker_name, end_timestamp, latency_list)
    store_latency_list_msg(app_name, category, worker_name, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(worker_name, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, category, worker_name, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, category, worker_name, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, category, worker_name, msg_timestamp)
    {:noreply, socket}
  end

  def handle_in("metrics", %{"category" => "computation"} = metrics_msg, socket) do
    "metrics:" <> app_name = socket.topic
    %{"category" => category, "latency_list" => latency_list,
      "timestamp" => end_timestamp, "period" => period, "name" => pipeline_key,
      "min" => _min, "max" => _max} = metrics_msg
    [pipeline_and_worker_name, computation_name] = String.split(pipeline_key, ":", parts: 2)
    [pipeline_name, _worker_name] = String.split(pipeline_and_worker_name, "@")
    #By Worker
    latency_list_msg = create_latency_list_msg(pipeline_key, end_timestamp, latency_list)
    store_latency_list_msg(app_name, "computation-by-worker", pipeline_key, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(pipeline_key, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, "computation-by-worker", pipeline_key, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, "computation-by-worker", pipeline_key, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, "computation-by-worker", pipeline_key, msg_timestamp)
    AppConfigStore.add_pipeline_computation_to_app_config(app_name, pipeline_and_worker_name, pipeline_key, "computation-by-worker:" <> pipeline_key)
    # By Computation
    latency_list_msg = create_latency_list_msg(computation_name, end_timestamp, latency_list)
    store_latency_list_msg(app_name, category, computation_name, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(computation_name, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, category, computation_name, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, category, computation_name, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, category, computation_name, msg_timestamp)
    AppConfigStore.add_pipeline_computation_to_app_config(app_name, pipeline_name, computation_name, "computation:" <> computation_name)
    {:noreply, socket}
  end

  def handle_in("metrics", %{"category" => "pipeline-ingestion"} = metrics_msg, socket) do
    "metrics:" <> app_name = socket.topic
    %{"category" => category, "latency_list" => latency_list,
      "timestamp" => end_timestamp, "period" => period, "name" => pipeline_key,
      "min" => _min, "max" => _max} = metrics_msg
    throughput_msg = create_throughput_msg_from_latency_list(pipeline_key, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, category, pipeline_key, throughput_msg)
    {_response, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_key, msg_timestamp)
    {:noreply, socket}
  end

  def handle_in("metrics", metrics_msg, socket) do
    "metrics:" <> app_name = socket.topic
    %{"category" => category, "latency_list" => latency_list,
      "timestamp" => end_timestamp, "period" => period, "name" => pipeline_key,
      "min" => _min, "max" => _max} = metrics_msg
    latency_list_msg = create_latency_list_msg(pipeline_key, end_timestamp, latency_list)
    store_latency_list_msg(app_name, category, pipeline_key, latency_list_msg)
    throughput_msg = create_throughput_msg_from_latency_list(pipeline_key, end_timestamp, period, latency_list)
    msg_timestamp = throughput_msg["time"]
    store_period_throughput_msg(app_name, category, pipeline_key, throughput_msg)
    {_response, _pid} = find_or_start_latency_bins_worker(app_name, category, pipeline_key, msg_timestamp)
    {_response, _pid} = find_or_start_throughput_workers(app_name, category, pipeline_key, msg_timestamp)
    {:noreply, socket}
  end

  defp create_latency_list_msg(pipeline_key, timestamp, latency_list) do
    %{"time" => timestamp, "pipeline_key" => pipeline_key, "latency_list" => latency_list}
  end

  defp store_latency_list_msg(app_name, category, pipeline_key, latency_list_msg) do
    log_name = generate_latency_bins_log_name(app_name, category, pipeline_key)
    :ok = MessageLog.Supervisor.lookup_or_create(log_name)
    MessageLog.log_latency_list_message(log_name, latency_list_msg)
  end

  defp create_throughput_msg_from_latency_list(pipeline_key, timestamp, period, latency_list) do
    total_throughput = latency_list
      |> Enum.reduce(0, fn bin_count, acc -> bin_count + acc end)
    %{"time" => timestamp, "pipeline_key" => pipeline_key,
      "period" => period, "total_throughput" => total_throughput}
  end

  defp store_period_throughput_msg(app_name, category, pipeline_key, period_throughput_msg) do
    log_name = generate_throughput_log_name(app_name, category, pipeline_key)
    :ok = MessageLog.Supervisor.lookup_or_create log_name
    MessageLog.log_period_throughput_message(log_name, period_throughput_msg)
  end

  defp generate_throughput_log_name(app_name, category, pipeline_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::throughput:" <> pipeline_key
  end

  defp generate_latency_bins_log_name(app_name, category, pipeline_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::latency-bins:" <> pipeline_key
  end

  defp find_or_start_throughput_workers(app_name, category, pipeline_key, msg_timestamp) do
    log_name = generate_throughput_log_name(app_name, category, pipeline_key)
    total_throughput_args = [log_name: log_name, interval_key: "last-1-sec", pipeline_key: pipeline_key, app_name: app_name, category: category, msg_timestamp: msg_timestamp]
    ThroughputsBroadcaster.Supervisor.find_or_start_worker(total_throughput_args)
    throughput_stats_args = [log_name: log_name, interval_key: "last-5-mins", pipeline_key: pipeline_key, app_name: app_name, category: category, stats_interval: 300, msg_timestamp: msg_timestamp]
    ThroughputStatsBroadcaster.Supervisor.find_or_start_worker(throughput_stats_args)
  end

  defp find_or_start_latency_bins_worker(app_name, category, pipeline_key, msg_timestamp) do
    log_name = generate_latency_bins_log_name(app_name, category, pipeline_key)
    args = [log_name: log_name, interval_key: "last-5-mins",  pipeline_key: pipeline_key,
      aggregate_interval: 300, app_name: app_name, category: category, msg_timestamp: msg_timestamp]
    LatencyStatsBroadcaster.Supervisor.find_or_start_worker(args)
  end
end
