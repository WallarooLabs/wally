defmodule MetricsReporterUI.ThroughputsBroadcaster.Supervisor do
  use Supervisor

  alias MetricsReporterUI.ThroughputsBroadcaster.Worker
  @name MetricsReporterUI.ThroughputsBroadcaster.Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: @name)
  end

  def start_worker([log_name: _log_name, interval_key: _interval_key,
    pipeline_key: _pipeline_key, app_name: _app_name, category: _category,
    msg_timestamp: _msg_timestamp] = args) do
    Supervisor.start_child(@name, [args])
  end

  def find_or_start_worker([log_name: log_name, interval_key: interval_key,
    pipeline_key: _pipeline_key, app_name: _app_name, category: _category,
    msg_timestamp: _msg_timestamp] = args) do
      case :gproc.where({:n, :l, {:tb_worker, message_log_name(log_name, interval_key)}}) do
        :undefined ->
          start_worker(args)
        pid ->
          {:ok, pid}
      end
    end

  def init([]) do
    children = [
      worker(Worker, [], restart: :temporary)
    ]

    supervise(children, strategy: :simple_one_for_one)
  end

  defp message_log_name(pipeline_key, interval_key) do
    "log:" <> pipeline_key <> "::interval-key:" <> interval_key
  end

end
