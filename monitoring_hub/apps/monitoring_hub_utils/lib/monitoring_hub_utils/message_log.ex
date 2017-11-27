defmodule MonitoringHubUtils.MessageLog do
  use GenServer
  require Logger

  ## Client API

  def start_link(log_name, log_limit \\ 3600) do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [log_limit: log_limit], name: via_tuple(log_name))
  end

  def log_message(log_name, %{"time" => _} = message) do
    GenServer.call(via_tuple(log_name), {:log_message, message})
  end

  def log_throughput_message(log_name, %{"total_throughput" => _, "time" => _} = message) do
    GenServer.call(via_tuple(log_name), {:log_throughput_message, message})
  end

  def log_period_throughput_message(log_name, %{"total_throughput" => _, "time" => _,
    "period" => _} = message)
  do
    GenServer.call(via_tuple(log_name), {:log_period_throughput_message, message})
  end

  def log_latency_bins_message(log_name, %{"latency_bins" => _, "time" => _} = message) do
    GenServer.call(via_tuple(log_name), {:log_latency_bins_message, message})
  end

  def log_latency_list_message(log_name, %{"latency_list" => _, "time" => _} = message) do
    GenServer.call(via_tuple(log_name), {:log_latency_list_message, message})
  end

  def get_logs(log_name) do
    GenServer.call(via_tuple(log_name), {:get_logs, []})
  end

  def get_logs(log_name, [start_time: start_time]) do
    GenServer.call(via_tuple(log_name), {:get_logs, [start_time: start_time]})
  end

  def get_logs(log_name, [start_time: start_time, end_time: end_time]) do
    GenServer.call(via_tuple(log_name), {:get_logs, [start_time: start_time, end_time: end_time]})
  end

  ## Server Callbacks

  def init(args) do
    [{:log_limit, log_limit}] = args

    tid = :ets.new(:message_log, [:ordered_set])

    {:ok, %{tid: tid, log_limit: log_limit}}
  end

  def handle_call({:log_message, message}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    # Remove old messages prior to adding new message
    remove_old_messages(tid, log_limit)
    result = do_log_message(tid, message)
    {:reply, result, state}
  end

  def handle_call({:log_throughput_message, message}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    result = do_log_throughput_message(tid, message)
    {:reply, result, state}
  end

  def handle_call({:log_period_throughput_message, message}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    result = do_log_period_throughput_message(tid, message)
    {:reply, result, state}
  end

  def handle_call({:log_latency_bins_message, message}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    result = do_log_latency_bins_message(tid, message)
    {:reply, result, state}
  end

  def handle_call({:log_latency_list_message, message}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    result = do_log_latency_list_message(tid, message)
    {:reply, result, state}
  end

  def handle_call({:get_logs, []}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    results = :ets.match(tid, :"$1")
    |> Enum.map(fn [{_msg_timestamp, message}] -> message end)
    {:reply, results, state}
  end

  def handle_call({:get_logs, [start_time: start_time]}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    results = do_get_logs(tid, [{:start_time, start_time}])
    {:reply, results, state}
  end

  def handle_call({:get_logs, [start_time: start_time, end_time: end_time]}, _from, state) do
    %{tid: tid, log_limit: log_limit} = state

    remove_old_messages(tid, log_limit)
    results = do_get_logs(tid, [start_time: start_time, end_time: end_time])
    {:reply, results, state}
  end

  defp do_get_logs(tid, [start_time: start_time]) do
    messages = []
    {next_key, messages} =
      case :ets.lookup(tid, start_time) do
      [{_msg_timestamp, message}] ->
        {:ets.next(tid, start_time), List.insert_at(messages, -1, message)}
      [] ->
        {:ets.next(tid, start_time), messages}
    end

    get_logs_from_table(tid, [key: next_key, end_key: :"$end_of_table"], messages)
  end

  defp do_get_logs(tid, [start_time: start_time, end_time: end_time]) do
    messages = []
    {next_key, messages} =
      case :ets.lookup(tid, start_time) do
        [{_msg_timestamp, message}] ->
          {:ets.next(tid, start_time), List.insert_at(messages, -1, message)}
        [] ->
          {:ets.next(tid, start_time), messages}
      end
    get_logs_from_table(tid, [key: next_key, end_key: end_time], messages)
  end

  defp get_logs_from_table(_tid, [key: :"$end_of_table", end_key: _end_key], messages) do
    messages
  end

  defp get_logs_from_table(tid, [key: key, end_key: end_key], messages) do
    if key >= end_key do
      messages
    else
      [{_msg_timestamp, message}] = :ets.lookup(tid, key)
        messages = List.insert_at(messages, -1, message)
        next_key = :ets.next(tid, key)
        get_logs_from_table(tid, [key: next_key, end_key: end_key], messages)
    end
  end

  defp do_log_message(tid, message) do
    true = :ets.insert(tid, {message["time"], message})
    {:ok, message}
  end

  defp do_log_throughput_message(tid, throughput_message) do
    timestamp = throughput_message["time"]
      case :ets.lookup(tid, timestamp) do
        [{^timestamp, old_throughput_message}] ->
          updated_throughput_message =
            update_throughput_message(old_throughput_message, throughput_message)
          true = :ets.insert(tid, {timestamp, updated_throughput_message})
          {:ok, updated_throughput_message}
        [] ->
          true = :ets.insert(tid, {timestamp, throughput_message})
          {:ok, throughput_message}
      end
  end

  defp do_log_period_throughput_message(tid, throughput_message) do
    %{"period" => period, "time" => end_timestamp,
      "total_throughput" => total_throughput, "pipeline_key" => pipeline_key} = throughput_message
    start_timestamp = end_timestamp - period
    per_sec_throughput = round(total_throughput / period)
    # IO.inspect "logging for ts: #{end_timestamp}, period: #{period}, tt: #{total_throughput}, pst: #{per_sec_throughput}, pipeline_key: #{pipeline_key}"
    do_log_sec_throughput_message(tid, start_timestamp, end_timestamp, per_sec_throughput, pipeline_key)
  end

  defp do_log_sec_throughput_message(tid, start_timestamp, current_timestamp, total_throughput, pipeline_key) do
    throughput_message = create_throughput_msg(current_timestamp, pipeline_key, total_throughput)
    _result = do_log_throughput_message(tid, throughput_message)
    do_log_sec_throughput_message(tid, start_timestamp, current_timestamp - 1, total_throughput, pipeline_key)
  end

  defp do_log_latency_bins_message(tid, latency_bins_message) do
    timestamp = latency_bins_message["timestamp"]
    case :ets.lookup(tid, timestamp) do
      [{^timestamp, old_latency_bins_message}] ->
        updated_latency_bins_message = update_latency_bins_message(old_latency_bins_message, latency_bins_message)
        true = :ets.insert(tid, {timestamp, updated_latency_bins_message})
        {:ok, updated_latency_bins_message}
      [] ->
        true = :ets.insert(tid, {timestamp, latency_bins_message})
        {:ok, latency_bins_message}
    end
  end

  defp do_log_latency_list_message(tid, latency_list_message) do
    timestamp = latency_list_message["time"]
    latency_bins_message = convert_latency_list_to_map(latency_list_message)
    case :ets.lookup(tid, timestamp) do
      [{^timestamp, old_latency_bins_message}] ->
        updated_latency_bins_message = update_latency_bins_message(old_latency_bins_message, latency_bins_message)
        true = :ets.insert(tid, {timestamp, updated_latency_bins_message})
        {:ok, updated_latency_bins_message}
      [] ->
        true = :ets.insert(tid, {timestamp, latency_bins_message})
    end
  end

  defp update_throughput_message(old_throughput_message, throughput_message) do
    Map.update!(old_throughput_message, "total_throughput", &(&1 + throughput_message["total_throughput"]))
  end

  defp update_latency_bins_message(old_latency_bins_message, latency_bins_message) do
    Map.update!(old_latency_bins_message, "latency_bins", fn (latency_bins) ->
      Map.merge(latency_bins, latency_bins_message["latency_bins"], fn _k, v1, v2 ->
        v1 + v2
      end)
    end)
  end

  defp convert_latency_list_to_map(latency_list_message) do
    list = latency_list_message["latency_list"]
    {latency_bin_map, _} = list
      |> Enum.reduce({%{}, 0}, fn(bin, {map, i}) ->
        key = i |> to_string
        {Map.put(map, key, bin), i + 1}
      end)
    latency_list_message
      |> Map.put("latency_bins", latency_bin_map)
      |> Map.delete("latency_list")
  end

  def remove_old_messages(tid, log_limit) do
    msg_store_limit = :os.system_time(:seconds) - log_limit
    key = :ets.first(tid)
    :ok = do_remove_old_messages(tid, key, msg_store_limit)
  end

  defp do_remove_old_messages(tid, key, msg_store_limit) do
    # lookup the message in the table and check the time it was added
    case :ets.lookup(tid, key) do
      [{msg_time, _message}] = [stored_message] ->
        case msg_time > msg_store_limit do
          true ->
            # if the oldest even is inside the window of time we can return.
            # We know all events from here on are newer.
            :ok;
          false ->
            # Remove the message from the table and invoke
            # remove_old_messages_from_table again to check the next message
            true = :ets.delete_object(tid, stored_message)
            next_key = :ets.next(tid, key)
            do_remove_old_messages(tid, next_key, msg_store_limit)
        end
      [] ->
        # we are at the end of the set
        :ok
    end
  end

  defp create_throughput_msg(timestamp, pipeline_key, throughput) do
    %{"time" => timestamp, "pipeline_key" => pipeline_key, "total_throughput" => throughput}
  end

  defp via_tuple(log_name) do
    {:via, :gproc, process_name(log_name)}
  end

  defp process_name(log_name) do
    {:n, :l, {:message_log, log_name}}
  end
end
