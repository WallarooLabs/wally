defmodule MetricsReporterUI.StepChannelTest do
	use MetricsReporterUI.ChannelCase
  require Logger

  alias MetricsReporterUI.StepChannel
  alias MonitoringHubUtils.MessageLog

  setup do
    throughput_msg_log_name = "category:step::cat-name:NODE4::total-throughput:last-1-sec"
    :ok = MessageLog.Supervisor.lookup_or_create(throughput_msg_log_name)
    timestamp1 = :os.system_time(:seconds)
    older_timestamp = timestamp1 - 301
    timestamp2 = timestamp1 + 1
    throughput_msg1 = %{"total_throughput" => 100, "time" => timestamp1, "pipeline_key" => "NODE4"}
    throughput_msg2 = Map.put(throughput_msg1, "time", timestamp2)
    throughput_msg3 = Map.put(throughput_msg1, "time", older_timestamp)
    {:ok, ^throughput_msg1} = MessageLog.log_throughput_message(throughput_msg_log_name, throughput_msg1)
    {:ok, ^throughput_msg2} = MessageLog.log_throughput_message(throughput_msg_log_name, throughput_msg2)
    {:ok, ^throughput_msg3} = MessageLog.log_throughput_message(throughput_msg_log_name, throughput_msg3)

    {:ok, _, socket} = socket()
      |> subscribe_and_join(StepChannel, "step:NODE4")

    {:ok, socket: socket, throughput_msg1: throughput_msg1}
  end

  test "sends 'initial-total-throughputs' after joining", %{throughput_msg1: throughput_msg1} do
    payload = %{data: [throughput_msg1], pipeline_key: "NODE4"}
    assert_push "initial-total-throughputs:last-1-sec", ^payload
  end
end