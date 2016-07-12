defmodule MonitoringHubUtils.MessageLogTest do
  use ExUnit.Case
  require Logger

  alias MonitoringHubUtils.MessageLog

  setup do
    log_name = "test-log"
    log_limit = 3600
    {:ok, _} = MessageLog.start_link(log_name, log_limit)
    {:ok, log_name: log_name, log_limit: log_limit}
  end

  test "it logs a message", %{log_name: log_name} do
    timestamp = :os.system_time(:seconds)
    message = %{"time" => timestamp}
    assert {:ok, ^message} = MessageLog.log_message(log_name, message)

    messages = MessageLog.get_logs(log_name)
    assert Enum.find_value(messages, fn msg -> msg == message end)
  end

  test "it removes messages that are timestamped older than the log limit", %{log_name: log_name, log_limit: log_limit} do
    time_now = :os.system_time(:seconds)
    older_timestamp = time_now - log_limit
    old_message = %{"time" => older_timestamp}
    message = %{"time" => time_now}

    assert {:ok, ^old_message} = MessageLog.log_message(log_name, old_message)
    assert {:ok, ^message} = MessageLog.log_message(log_name, message)

    messages = MessageLog.get_logs(log_name)

    assert Enum.find_value(messages, fn msg -> msg == message end)
    refute Enum.find(messages, fn msg -> msg == old_message end)
  end

  test "it retrieves messages after a given timestamp", %{log_name: log_name} do
    time_now = :os.system_time(:seconds)
    message = %{"time" => time_now}
    older_timestamp = time_now - 500
    old_message = %{"time" => older_timestamp}
    retrieval_timestamp = time_now - 300

    assert {:ok, ^message} = MessageLog.log_message(log_name, message)
    assert {:ok, ^old_message} = MessageLog.log_message(log_name, old_message)

    messages = MessageLog.get_logs(log_name, [{:start_time, retrieval_timestamp}])

    assert Enum.find_value(messages, fn msg -> msg == message end)
    refute Enum.find(messages, fn msg -> msg == old_message end)
  end

  test "it retrieves messages between a given start & end time", %{log_name: log_name} do
    time_now = :os.system_time(:seconds)
    older_timestamp = time_now - 300
    newer_timestamp = time_now + 300
    start_time = time_now - 250
    end_time = time_now + 250

    msg_within_timeframe = %{"time" => time_now}
    assert {:ok, ^msg_within_timeframe} = MessageLog.log_message(log_name, msg_within_timeframe)
    msg_before_timeframe = %{"time" => older_timestamp}
    assert {:ok, ^msg_before_timeframe} = MessageLog.log_message(log_name, msg_before_timeframe)
    msg_after_timeframe = %{"time" => newer_timestamp}
    assert {:ok, ^msg_after_timeframe} = MessageLog.log_message(log_name, msg_after_timeframe)

    messages = MessageLog.get_logs(log_name, [start_time: start_time, end_time: end_time])
    assert Enum.find_value(messages, fn msg -> msg === msg_within_timeframe end)
    refute Enum.find(messages, fn msg -> msg === msg_after_timeframe end)
  end

  test "its logs a throughput message, updates if a partial is present" do
    timestamp = :os.system_time(:seconds)
    partial_throughput_msg1 = %{"total_throughput" => 100, "time" => timestamp}
    partial_throughput_msg2 = Map.put(partial_throughput_msg1, "total_throughput", 50)
    expected_throughput_msg = Map.put(partial_throughput_msg1, "total_throughput", 150)
    log_name = "throughput-test"
    {:ok, _} = MessageLog.start_link(log_name)

    assert {:ok, ^partial_throughput_msg1} = MessageLog.log_throughput_message(log_name, partial_throughput_msg1)
    assert {:ok, ^expected_throughput_msg} = MessageLog.log_throughput_message(log_name, partial_throughput_msg2)

    messages = MessageLog.get_logs(log_name)
    assert Enum.find_value(messages, fn msg -> msg == expected_throughput_msg end)
    refute Enum.find_value(messages, fn msg -> msg == partial_throughput_msg1 end)
    refute Enum.find_value(messages, fn msg -> msg == partial_throughput_msg2 end)
  end

  test "it logs a latency bins message, updates if a partial is present" do
    timestamp = :os.system_time(:seconds)
    latency_bins1 = %{"0.001" => 10, "10.0" => 30}
    latency_bins2 = %{"0.001" => 20, "1.0" => 30}
    latency_bins3 = %{"0.001" => 30, "1.0" => 30, "10.0" => 30}
    partial_latency_bins_msg1 = %{"time" => timestamp, "latency_bins" => latency_bins1}
    partial_latency_bins_msg2 = %{"time" => timestamp, "latency_bins" => latency_bins2}
    expected_latency_bins_msg = %{"time" => timestamp, "latency_bins" => latency_bins3}
    log_name = "latency_bins_test"
    {:ok, _} = MessageLog.start_link(log_name)

    assert {:ok, ^partial_latency_bins_msg1} = MessageLog.log_latency_bins_message(log_name, partial_latency_bins_msg1)
    assert {:ok, ^expected_latency_bins_msg} = MessageLog.log_latency_bins_message(log_name, partial_latency_bins_msg2)

    messages = MessageLog.get_logs(log_name)
    assert Enum.find_value(messages, fn msg -> msg == expected_latency_bins_msg end)
    refute Enum.find_value(messages, fn msg -> msg == partial_latency_bins_msg1 end)
    refute Enum.find_value(messages, fn msg -> msg == partial_latency_bins_msg2 end)
  end
end