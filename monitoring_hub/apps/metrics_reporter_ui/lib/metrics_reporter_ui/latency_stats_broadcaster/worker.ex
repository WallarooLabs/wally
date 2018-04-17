defmodule MetricsReporterUI.LatencyStatsBroadcaster.Worker do
  use GenServer
  require Logger

  alias MonitoringHubUtils.MessageLog
  alias MetricsReporter.LatencyStatsCalculator

  ## Client API

  def start_link([log_name: log_name, interval_key: interval_key,
    pipeline_key: _, aggregate_interval: _, app_name: _app_name,
    category: _category, msg_timestamp: _msg_timestamp] = args) do
    server_name = via_tuple(log_name, interval_key)
    {:ok, _pid} = GenServer.start_link(__MODULE__, args, name: server_name)
  end

  ## Server callbacks

  def init(args) do
    [log_name: log_name, interval_key: interval_key, pipeline_key: pipeline_key,
     aggregate_interval: aggregate_interval, app_name: app_name,
     category: category, msg_timestamp: msg_timestamp] = args
    msg_log_name = message_log_name(app_name, category, pipeline_key, interval_key)
    stats_msg_log_name = stats_message_log_name(app_name, category, pipeline_key, interval_key)
    bins_type = Application.get_env(:metrics_reporter_ui, :bins_type)
    bins = if bins_type == "demo" do
      ["10", "12", "14", "16", "18", "20", "22", "24", "26", "28", "30", "64"]
    else
      ["0", "10", "19", "20", "21", "22", "23", "24", "25", "26", "27", "30", "64"]
    end
    all_bins = get_all_bins()
    time_diff = calculate_time_diff(msg_timestamp)
    send(self(), :calculate_and_publish_latency_percentage_bins_msgs)
    {:ok, %{
      log_name: log_name, interval_key: interval_key, aggregate_interval: aggregate_interval, bins: bins, all_bins: all_bins,
      category: category, pipeline_key: pipeline_key, msg_log_name: msg_log_name, stats_msg_log_name: stats_msg_log_name,
      time_diff: time_diff, start_time: msg_timestamp, app_name: app_name}}
  end

  def handle_info(:calculate_and_publish_latency_percentage_bins_msgs, state) do
    %{log_name: log_name, msg_log_name: msg_log_name, interval_key: interval_key, stats_msg_log_name: stats_msg_log_name,
    pipeline_key: pipeline_key, aggregate_interval: aggregate_interval, category: category, bins: bins, all_bins: all_bins,
    time_diff: time_diff, start_time: _start_time, app_name: app_name} = state
    :timer.sleep(2500)
    current_time = calculate_time_diff(time_diff)
    logs_start_time = current_time - aggregate_interval
    {latency_bins_list, latency_bins_percentile_data} =
      case get_latency_bins_list(log_name, logs_start_time) do
        [] ->
          {[], LatencyStatsCalculator.generate_empty_latency_percentile_bin_stats()}
        throughputs_list ->
          all_latency_percentage_bins_data = LatencyStatsCalculator.calculate_latency_percentage_bins_data(throughputs_list, all_bins)
          cumulative_latency_percentage_bins_data = LatencyStatsCalculator.calculate_cumulative_latency_percentage_bins_data(all_latency_percentage_bins_data)
          {throughputs_list, LatencyStatsCalculator.calculate_latency_percentile_bin_stats(cumulative_latency_percentage_bins_data)}
      end

    latency_percentage_bins_data = LatencyStatsCalculator.calculate_latency_percentage_bins_data(latency_bins_list, bins)
    latency_percentage_bins_msg = generate_latency_percentage_bins_msg(latency_percentage_bins_data, app_name, pipeline_key, current_time)
    {:ok, latency_percentage_bins_msg} = store_latest_latency_percentage_bins_msg(msg_log_name, latency_percentage_bins_msg)
    broadcast_latest_latency_percentage_bins_msg(category, app_name, pipeline_key, interval_key, latency_percentage_bins_msg)

    latency_bins_percentile_stats_msg = generate_latency_bins_percentile_stats_msg(latency_bins_percentile_data, app_name, pipeline_key, current_time)
    {:ok, ^latency_bins_percentile_stats_msg} = store_latest_latency_bins_percentile_stats_msg(stats_msg_log_name, latency_bins_percentile_stats_msg)
    broadcast_latest_latency_bins_percentile_stats_msg(category, app_name, pipeline_key, interval_key, latency_bins_percentile_stats_msg)
    send(self(), :calculate_and_publish_latency_percentage_bins_msgs)
    {:noreply, state}
  end

  defp message_log_name(app_name, category, pipeline_key, interval_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::cat-name:" <> pipeline_key <> "::latency-percentage-bins:" <> interval_key
  end

  defp stats_message_log_name(app_name, category, pipeline_key, interval_key) do
    "app_name:" <> app_name <> "::category:" <> category <> "::cat-name:" <> pipeline_key <> "::latency-percentile-bin-stats:" <> interval_key
  end

  defp generate_worker_name(log_name, interval_key) do
    "log:" <> log_name <> "::interval-key:" <> interval_key
  end

  defp via_tuple(log_name, interval_key) do
    worker_name = generate_worker_name(log_name, interval_key)
    {:via, :gproc, {:n, :l, {:lba_worker, worker_name}}}
  end

  defp get_latency_bins_list(log_name, start_time) do
    :ok = MessageLog.Supervisor.lookup_or_create(log_name)
    MessageLog.get_logs(log_name, [start_time: start_time])
  end

  defp generate_latency_bins_percentile_stats_msg(latency_bins_percentile_data, app_name, pipeline_key, time_now) do
    %{"app_name" => app_name, "pipeline_key" => pipeline_key,
    "time" => time_now, "latency_stats" => latency_bins_percentile_data}
  end

  def store_latest_latency_bins_percentile_stats_msg(msg_log_name, stats_msg) do
    :ok = MessageLog.Supervisor.lookup_or_create msg_log_name
    {:ok, ^stats_msg} = MessageLog.log_message(msg_log_name, stats_msg)
  end


  defp broadcast_latest_latency_percentage_bins_msg(category, app_name, pipeline_key, interval_key, latency_percentage_bins_msg) do
    topic = MonitoringHubUtils.Helpers.create_channel_name(category, app_name, pipeline_key)
    event = "latency-percentage-bins:" <> interval_key
    MetricsReporterUI.Endpoint.broadcast! topic, event, latency_percentage_bins_msg
  end

  def broadcast_latest_latency_bins_percentile_stats_msg(category, app_name, pipeline_key, interval_key, stats_msg) do
    topic = MonitoringHubUtils.Helpers.create_channel_name(category, app_name, pipeline_key)
    event = "latency-percentile-bin-stats:" <> interval_key
    MetricsReporterUI.Endpoint.broadcast! topic, event, stats_msg
  end

  defp store_latest_latency_percentage_bins_msg(msg_log_name, latency_percentage_bins_msg) do
    :ok = MessageLog.Supervisor.lookup_or_create(msg_log_name)
    {:ok, ^latency_percentage_bins_msg} = MessageLog.log_message(msg_log_name, latency_percentage_bins_msg)
  end

  defp generate_empty_latency_percentage_bins_msg(timestamp, app_name, pipeline_key) do
    %{
      "time" => timestamp,
      "latency_bins" => LatencyStatsCalculator.get_empty_latency_percentage_bins_data,
      "pipeline_key" => pipeline_key,
      "app_name" => app_name
    }
  end

  defp get_all_bins do
    Enum.reduce(0..64, [], fn bin, list ->
      List.insert_at(list, -1, bin |> to_string)
    end)
  end

  defp generate_latency_percentage_bins_msg(latency_percentage_bins_data, app_name, pipeline_key, time_now) do
    empty_latency_percentage_bins_msg = generate_empty_latency_percentage_bins_msg(time_now, app_name, pipeline_key)
    Map.put(empty_latency_percentage_bins_msg, "latency_bins", latency_percentage_bins_data)
  end

  defp calculate_time_diff(timestamp) do
    :os.system_time(:seconds) - timestamp
  end

end
