defmodule MetricsReporterUI.ThroughputStatsBroadcaster.Worker do
	use GenServer
  require Logger
  require Integer

  alias MonitoringHubUtils.MessageLog

  ## Client API
  def start_link([log_name: log_name, interval_key: interval_key,
    pipeline_key: _pipeline_key, app_name: _app_name, category: _category,
    stats_interval: _stats_interval, msg_timestamp: _msg_timestamp] = args) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, args, name: via_tuple(log_name, interval_key))
  end

  ## Server Callbacks
  def init(args) do
    [log_name: log_name, interval_key: interval_key,
    pipeline_key: pipeline_key, app_name: app_name, category: category,
    stats_interval: stats_interval, msg_timestamp: msg_timestamp] = args
    msg_log_name = message_log_name(app_name, category, pipeline_key, interval_key)
    time_diff = calculate_time_diff(msg_timestamp)
    send(self(), :get_and_broadcast_latest_throughput_stat_msgs)
    {:ok, %{
      log_name: log_name, interval_key: interval_key, category: category, app_name: app_name,
      msg_log_name: msg_log_name, pipeline_key: pipeline_key, stats_interval: stats_interval,
      time_diff: time_diff, start_time: msg_timestamp
    }}
  end

  def handle_info(:get_and_broadcast_latest_throughput_stat_msgs, state) do
    %{log_name: log_name, interval_key: interval_key, msg_log_name: msg_log_name,
      app_name: _app_name, category: category, pipeline_key: pipeline_key,
      stats_interval: stats_interval, time_diff: time_diff, start_time: start_time} = state
    :timer.sleep(2500)
    current_time = calculate_time_diff(time_diff)
    expected_start_time = current_time - stats_interval
    logs_start_time = if (expected_start_time < start_time), do: start_time, else: expected_start_time
    received_throughput_msgs = get_throughput_msgs(log_name, logs_start_time, current_time)
    throughput_stats_msg = case received_throughput_msgs do
      [] ->
        create_throughput_stats_msg(empty_throughput_stats_msg(), pipeline_key, current_time)
      throughput_msgs ->
        throughput_stats = MetricsReporter.ThroughputStatsCalculator.calculate_throughput_stats(throughput_msgs)
        create_throughput_stats_msg(throughput_stats, pipeline_key, current_time)
    end
    {:ok, ^throughput_stats_msg} = store_throughput_stats_msg(msg_log_name, throughput_stats_msg)
    broadcast_throughput_stats_msg(category, pipeline_key, interval_key, throughput_stats_msg)
    send(self(), :get_and_broadcast_latest_throughput_stat_msgs)
    {:noreply, state}
  end

  defp get_throughput_msgs(log_name, start_time, end_time) do
    :ok = MessageLog.Supervisor.lookup_or_create log_name
     MessageLog.get_logs(log_name, [start_time: start_time, end_time: end_time])
  end

  defp create_throughput_stats_msg(throughput_stats, pipeline_key, time_now) do
    %{
      "time" => time_now,
      "pipeline_key" => pipeline_key,
      "throughput_stats" => throughput_stats
    }
  end

  defp empty_throughput_stats_msg do
    %{"min" => 0, "med" => 0, "max" => 0}
  end

  defp store_throughput_stats_msg(msg_log_name, throughput_stats_msg) do
    :ok = MessageLog.Supervisor.lookup_or_create msg_log_name
    {:ok, ^throughput_stats_msg} = MessageLog.log_message(msg_log_name, throughput_stats_msg)
  end

  defp broadcast_throughput_stats_msg(category, pipeline_key, interval_key, throughput_stats_msg) do
    topic = category <> ":" <> pipeline_key
    event = "throughput-stats:" <> interval_key
    MetricsReporterUI.Endpoint.broadcast! topic, event, throughput_stats_msg
  end

  defp message_log_name(app_name, category, pipeline_key, interval_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::cat-name:" <> pipeline_key <> "::throughput-stats:" <> interval_key
  end

  defp generate_worker_name(log_name, interval_key) do
    "log:" <> log_name <> "::interval-key:" <> interval_key
  end

  defp via_tuple(log_name, interval_key) do
    worker_name = generate_worker_name(log_name, interval_key)
    {:via, :gproc, {:n, :l, {:tsb_worker, worker_name}}}
  end

  defp calculate_time_diff(timestamp) do
    :os.system_time(:seconds) - timestamp
  end

end
