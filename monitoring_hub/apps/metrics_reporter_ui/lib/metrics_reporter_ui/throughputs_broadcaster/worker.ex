defmodule MetricsReporterUI.ThroughputsBroadcaster.Worker do
  use GenServer
  require Logger
  require Integer

  alias MonitoringHubUtils.MessageLog
  alias MonitoringHubUtils.Stores.AppConfigStore

  ## Client API
  def start_link([log_name: log_name, interval_key: interval_key, pipeline_key: _pipeline_key,
    app_name: _app_name, category: _category, msg_timestamp: _msg_timestamp] = args) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, args, name: via_tuple(log_name, interval_key))
  end

  ## Server Callbacks

  def init(args) do
    [log_name: log_name, interval_key: interval_key, pipeline_key: pipeline_key,
    app_name: app_name, category: category, msg_timestamp: msg_timestamp] = args
    msg_log_name = message_log_name(app_name, category, pipeline_key, interval_key)
    time_diff = calculate_time_diff(msg_timestamp)
    send(self(), :get_and_broadcast_latest_throughput_msgs)
    {:ok, %{
      log_name: log_name, interval_key: interval_key, category: category, app_name: app_name,
      msg_log_name: msg_log_name, pipeline_key: pipeline_key,
      time_diff: time_diff, start_time: msg_timestamp
    }}
  end

  def handle_info(:get_and_broadcast_latest_throughput_msgs, state) do
    %{log_name: log_name, interval_key: interval_key, msg_log_name: msg_log_name,
      app_name: app_name, category: category, pipeline_key: pipeline_key,
      time_diff: time_diff, start_time: start_time} = state
      :timer.sleep(1000)
      current_time = calculate_time_diff(time_diff)
      expected_start_time = current_time - 300
      logs_start_time = if (expected_start_time < start_time), do: start_time, else: expected_start_time
      received_throughput_msgs = get_throughput_msgs(log_name, logs_start_time, current_time)
      complete_throughput_msgs = for timestamp <- logs_start_time..current_time, into: [] do
        Enum.find(received_throughput_msgs, generate_empty_throughput_msg(pipeline_key, timestamp), fn throughput_msg ->
          throughput_msg["time"] == timestamp
        end)
      end
      store_latest_throughput_msgs(msg_log_name, complete_throughput_msgs)
      topic_name =  category <> ":" <> pipeline_key
      event_name = get_event_name(interval_key)
      {:ok, _app_config} = AppConfigStore.add_metrics_channel_to_app_config(app_name, category, topic_name)
      broadcast_latest_throughput_msgs(topic_name, event_name, pipeline_key, complete_throughput_msgs)
      send(self(), :get_and_broadcast_latest_throughput_msgs)
      {:noreply, state}
  end

  defp get_throughput_msgs(log_name, start_time, end_time) do
    :ok = MessageLog.Supervisor.lookup_or_create log_name
     MessageLog.get_logs(log_name, [start_time: start_time, end_time: end_time])
  end

  defp store_latest_throughput_msgs(msg_log_name, throughput_msgs) do
    :ok = MessageLog.Supervisor.lookup_or_create msg_log_name
    Enum.each(throughput_msgs, fn throughput_msg ->
      {:ok, ^throughput_msg} = MessageLog.log_message(msg_log_name, throughput_msg)
    end)
  end

  defp broadcast_latest_throughput_msgs(topic, event, pipeline_key, throughput_msgs) do
      MetricsReporterUI.Endpoint.broadcast! topic, event, %{"data" => throughput_msgs, "pipeline_key" => pipeline_key}
  end

  defp via_tuple(log_name, interval_key) do
    worker_name = generate_worker_name(log_name, interval_key)
    {:via, :gproc, {:n, :l, {:tb_worker, worker_name}}}
  end

  defp message_log_name(_app_name, category, pipeline_key, interval_key) do
    "category:" <> category <>  "::cat-name:" <> pipeline_key <> "::" <> get_event_name(interval_key)
  end

  defp get_event_name(interval_key) do
    "total-throughput:" <> interval_key
  end

  defp generate_worker_name(log_name, interval_key) do
    "log:" <> log_name <> "::interval-key:" <> interval_key
  end

  defp generate_empty_throughput_msg(pipeline_key, timestamp) do
    %{
        "pipeline_key" => pipeline_key,
        "total_throughput" => 0,
        "time" => timestamp
    }
  end

  defp calculate_time_diff(timestamp) do
    :os.system_time(:seconds) - timestamp
  end

end
