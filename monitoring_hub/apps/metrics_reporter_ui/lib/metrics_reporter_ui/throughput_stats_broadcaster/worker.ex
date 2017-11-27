defmodule MetricsReporterUI.ThroughputStatsBroadcaster.Worker do
	use GenServer
  require Logger
  require Integer

  alias MonitoringHubUtils.MessageLog

  ## Client API
  def start_link([log_name: log_name, interval_key: interval_key, pipeline_key: _pipeline_key, app_name: _app_name, category: _category, stats_interval: _stats_interval] = args) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, args, name: via_tuple(log_name, interval_key))
  end

  ## Server Callbacks
  def init(args) do
    [log_name: log_name, interval_key: interval_key, pipeline_key: pipeline_key, app_name: app_name, category: category, stats_interval: stats_interval] = args
    msg_log_name = message_log_name(app_name, category, pipeline_key, interval_key)
    send(self(), :get_and_broadcast_latest_throughput_stat_msgs)
    {:ok, %{
      log_name: log_name, interval_key: interval_key, category: category, app_name: app_name,
      msg_log_name: msg_log_name, pipeline_key: pipeline_key, stats_interval: stats_interval
    }}
  end

  def handle_info(:get_and_broadcast_latest_throughput_stat_msgs, state) do
    %{log_name: log_name, interval_key: interval_key, msg_log_name: msg_log_name,
      app_name: _app_name, category: category, pipeline_key: pipeline_key,
      stats_interval: stats_interval} = state
    :timer.sleep(2500)
    time_now = :os.system_time(:seconds)
    start_time = time_now - stats_interval
    case get_throughput_msgs(log_name, start_time) do
      [] ->
        :ok
      [_partial_throughput_msg] ->
        :ok
      [_first_throughput_msg, _second_throughput_msg] ->
        :ok
      throughput_msgs ->
        %{"time" => timestamp} = List.last(throughput_msgs)
        updated_throughput_msgs = if Integer.is_odd(timestamp) do
          List.delete_at(throughput_msgs, -1)
        else
          throughput_msgs
        end
        throughput_stats = MetricsReporter.ThroughputStatsCalculator.calculate_throughput_stats(updated_throughput_msgs)
        throughput_stats_msg = create_throughput_stats_msg(throughput_stats, pipeline_key, time_now)
        {:ok, ^throughput_stats_msg} = store_throughput_stats_msg(msg_log_name, throughput_stats_msg)
        broadcast_throughput_stats_msg(category, pipeline_key, interval_key, throughput_stats_msg)
    end
    send(self(), :get_and_broadcast_latest_throughput_stat_msgs)
    {:noreply, state}
  end

  defp get_throughput_msgs(log_name, start_time) do
    :ok = MessageLog.Supervisor.lookup_or_create log_name
    throughput_msgs = MessageLog.get_logs(log_name, [start_time: start_time])
    _throughput_msgs_without_partial = List.delete_at(throughput_msgs, -1)
  end

  defp create_throughput_stats_msg(throughput_stats, pipeline_key, time_now) do
    %{
      "time" => time_now,
      "pipeline_key" => pipeline_key,
      "throughput_stats" => throughput_stats
    }
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
end
