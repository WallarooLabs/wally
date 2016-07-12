defmodule MonitoringHubUtils.MessageLog.Supervisor do
  use Supervisor

  @name MonitoringHubUtils.MessageLog.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def start_message_log(log_name, log_limit \\ 3600) do
    Supervisor.start_child(@name, [log_name, log_limit])
  end

  def lookup_or_create(log_name) do
    unless log_exists?(log_name) do
      start_message_log(log_name)
    end
    :ok
  end

  def log_exists?(log_name) do
    case :gproc.whereis_name(message_log_name(log_name)) do
      :undefined ->
        false
      _pid ->
        true
    end
  end

  def init([]) do
    children = [
      worker(MonitoringHubUtils.MessageLog, [], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  defp message_log_name(log_name) do
    {:n, :l, {:message_log, log_name}}  
  end

end