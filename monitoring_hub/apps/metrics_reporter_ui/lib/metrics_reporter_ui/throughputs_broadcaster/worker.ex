defmodule MetricsReporterUI.ThroughputsBroadcaster.Worker do
  use GenServer
  require Logger
  require Integer

  alias MonitoringHubUtils.MessageLog
  alias MonitoringHubUtils.Stores.AppConfigStore

  ## Client API
  def start_link([log_name: log_name, interval_key: interval_key, pipeline_key: _pipeline_key, app_name: _app_name, category: _category] = args) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, args, name: via_tuple(log_name, interval_key))
  end

  ## Server Callbacks

  def init(args) do
    [log_name: log_name, interval_key: interval_key, pipeline_key: pipeline_key, app_name: app_name, category: category] = args
    msg_log_name = message_log_name(app_name, category, pipeline_key, interval_key)
    send(self(), :get_and_broadcast_latest_throughput_msgs)
    {:ok, %{
      log_name: log_name, interval_key: interval_key, category: category, app_name: app_name,
      msg_log_name: msg_log_name, pipeline_key: pipeline_key, last_msg_ts: 0
    }}
  end

  def handle_info(:get_and_broadcast_latest_throughput_msgs, state) do
    %{log_name: log_name, interval_key: interval_key, msg_log_name: msg_log_name,
      app_name: app_name, category: category, pipeline_key: pipeline_key, last_msg_ts: last_msg_ts} = state
      :timer.sleep(1000)
      state =
        case get_throughput_msgs(log_name, last_msg_ts) do
          [] ->
            :ok
            state
          [_single_throughput_msg] ->
            :ok
            state
          [_first_throughput_msg, _second_throughput_msg] ->
            :ok
            state
          throughput_msgs ->
            %{"time" => timestamp} = List.last(throughput_msgs)
            updated_throughput_msgs = if Integer.is_odd(timestamp) do
              List.delete_at(throughput_msgs, -1)
            else
              throughput_msgs
            end
            store_latest_throughput_msgs(msg_log_name, updated_throughput_msgs)
            topic_name =  category <> ":" <> pipeline_key
            event_name = get_event_name(interval_key)
            {:ok, _app_config} = AppConfigStore.add_metrics_channel_to_app_config(app_name, category, topic_name)
            broadcast_latest_throughput_msgs(topic_name, event_name, updated_throughput_msgs)
            new_last_msg_ts = get_last_throughput_msg_ts(updated_throughput_msgs)
            Map.put(state, :last_msg_ts, new_last_msg_ts)
        end
      send(self(), :get_and_broadcast_latest_throughput_msgs)
      {:noreply, state}
  end

  defp get_throughput_msgs(log_name, start_time) do
    :ok = MessageLog.Supervisor.lookup_or_create log_name
    throughput_list = MessageLog.get_logs(log_name, [start_time: start_time + 1])
    _throughput_msgs_without_partial = List.delete_at(throughput_list, -1)
  end

  defp store_latest_throughput_msgs(msg_log_name, throughput_msgs) do
    :ok = MessageLog.Supervisor.lookup_or_create msg_log_name
    Enum.each(throughput_msgs, fn throughput_msg ->
      {:ok, ^throughput_msg} = MessageLog.log_message(msg_log_name, throughput_msg)
    end)
  end

  defp broadcast_latest_throughput_msgs(topic, event, throughput_msgs) do
    Enum.each(throughput_msgs, fn throughput_msg ->
      MetricsReporterUI.Endpoint.broadcast! topic, event, throughput_msg
    end)
  end

  defp get_last_throughput_msg_ts(throughput_msgs) do
    throughput_msg = List.last(throughput_msgs)
    throughput_msg["time"]
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

end
