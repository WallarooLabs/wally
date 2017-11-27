defmodule MonitoringHubUtils.Stores.AppConfigStore do
  use GenServer
  require Logger

  ## CLient API

  def start_link do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_or_create_app_config(app_name) do
    GenServer.call(__MODULE__, {:get_or_create_app_config, app_name})
  end

  def get_app_config(app_name) do
    GenServer.call(__MODULE__, {:get_app_config, app_name})
  end

  def get_app_names do
    GenServer.call(__MODULE__, :get_app_names)
  end

  def store_app_config(app_name, app_config) do
    GenServer.call(__MODULE__, {:store_app_config, [app_name: app_name, app_config: app_config]})
  end

  def create_initial_app_config(app_name) do
    GenServer.call(__MODULE__, {:create_initial_app_config, [app_name: app_name]})
  end

  def add_metrics_channel_to_app_config(app_name, category, channel) do
    GenServer.call(__MODULE__, {:add_metrics_channel_to_app_config, [app_name: app_name, category: category, channel: channel]})
  end

  def add_pipeline_computation_to_app_config(app_name, pipeline_name, computation_name, channel) do
    GenServer.call(__MODULE__, {:add_pipeline_computation_to_app_config, [app_name: app_name,
      pipeline_name: pipeline_name, compuation_name: computation_name, channel: channel]})
  end

  def add_worker_to_app_config(app_name, worker_name) do
    GenServer.call(__MODULE__, {:add_worker_to_app_config, [app_name: app_name, worker_name: worker_name]})
  end

  ## Server callbacks
  def init([]) do
    tid = :ets.new(:app_config_store, [:named_table, :set])
    {:ok, %{tid: tid}}
  end

  def handle_call({:get_app_config, app_name}, _from, %{tid: tid} = state) do
    result = case :ets.lookup(tid, app_name) do
      [{^app_name, app_config}] ->
        {:ok, app_config}
      [] ->
        {:error, "app config not found for: #{app_name}"}
    end
    {:reply, result, state}
  end

  def handle_call({:get_or_create_app_config, app_name}, _from, %{tid: tid} = state) do
    app_config = case :ets.lookup(tid, app_name) do
      [{^app_name, app_config}] ->
        app_config
      [] ->
        initial_app_config = do_create_initial_app_config(app_name)
        true = :ets.insert(tid, {app_name, initial_app_config})
        initial_app_config
    end
    {:reply, {:ok, app_config}, state}
  end

  def handle_call({:store_app_config, [app_name: app_name, app_config: app_config]},
    _from, %{tid: tid} = state) do
    true = :ets.insert(tid, {app_name, app_config})
    {:reply, {:ok, app_config}, state}
  end

  def handle_call({:create_initial_app_config, [app_name: app_name]}, _from, %{tid: tid} = state) do
    app_config = do_create_initial_app_config(app_name)
    true = :ets.insert(tid, {app_name, app_config})
    {:reply, {:ok, app_config}, state}
  end

  def handle_call({:add_metrics_channel_to_app_config, [app_name: app_name, category: category, channel: channel]},
    _from, %{tid: tid} = state) do
    app_config = case :ets.lookup(tid, app_name) do
      [{^app_name, config}] ->
        config
      [] ->
        do_create_initial_app_config(app_name)
    end
    new_app_config = do_add_metrics_channel_to_app_config(app_config, category, channel)
    if (app_config == new_app_config) do
      {:reply, {:ok, app_config}, state}
    else
      true = :ets.insert(tid, {app_name, new_app_config})
      {:reply, {:ok, new_app_config}, state}
    end
  end

  def handle_call({:add_pipeline_computation_to_app_config, [app_name: app_name, pipeline_name: pipeline_name,
    compuation_name: computation_name, channel: channel]}, _from, %{tid: tid} = state) do
    app_config = case :ets.lookup(tid, app_name) do
      [{^app_name, config}] ->
        config
      [] ->
        do_create_initial_app_config(app_name)
    end
    new_app_config = do_add_pipeline_computation_to_app_config(app_config, pipeline_name, computation_name, channel)
    if (app_config == new_app_config) do
      {:reply, {:ok, app_config}, state}
    else
      true = :ets.insert(tid, {app_name, new_app_config})
      {:reply, {:ok, new_app_config}, state}
    end
  end

  def handle_call({:add_worker_to_app_config, [app_name: app_name, worker_name: worker_name]},
      _from, %{tid: tid} = state) do
    app_config = case :ets.lookup(tid, app_name) do
      [{^app_name, config}] ->
        config
      [] ->
        do_create_initial_app_config(app_name)
    end
    new_app_config = do_add_worker_name_to_app_config(app_config, worker_name)
    if (app_config == new_app_config) do
      {:reply, {:ok, app_config}, state}
    else
      true = :ets.insert(tid, {app_name, new_app_config})
      {:reply, {:ok, new_app_config}, state}
    end
  end

  def handle_call(:get_app_names, _from, %{tid: tid} = state) do
    app_names = get_table_keys(tid)
    {:reply, {:ok, app_names}, state}
  end

  defp do_create_initial_app_config(app_name) do
    %{"app_name" => app_name,
      "metrics" => %{
        "start-to-end" => [],
        "node-ingress-egress" => [],
        "computation" => [],
        "pipeline" => [],
        "pipeline-ingestion" => [],
        "computation-by-worker" => %{},
        "start-to-end-by-worker" => %{},
        "node-ingress-egress-by-pipeline" => %{},
        "pipeline-computations" => %{}
        },
      "workers" => []}
  end

  defp do_add_worker_name_to_app_config(app_config, worker_name) do
    update_in(app_config, ["workers"], fn worker_list ->
      worker_list ++ [worker_name]
        |> Enum.sort
        |> Enum.uniq
    end)

  end

  defp do_add_metrics_channel_to_app_config(app_config,  "computation-by-worker" = category, channel) do
    update_in(app_config, ["metrics", category], fn computations_map ->
      [_category, pipeline_and_worker_name, computation_name] = String.split(channel, ":", parts: 3)
      [_pipeline_name, worker_name] = String.split(pipeline_and_worker_name, "@")
      computations_map
        |> Map.update(computation_name, [channel], fn channel_list ->
          channel_list ++ [channel]
            |> Enum.sort
            |> Enum.uniq
        end)
        |> Map.update(worker_name, [channel], fn channel_list ->
          channel_list ++ [channel]
           |> Enum.sort
           |> Enum.uniq
        end)
    end)
  end

  defp do_add_metrics_channel_to_app_config(app_config,  "start-to-end-by-worker" = category, channel) do
    update_in(app_config, ["metrics", category], fn pipelines_map ->
      [category_and_pipeline_name, worker_name] = String.split(channel, "@")
      [_category, pipeline_name] = String.split(category_and_pipeline_name, ":")
      pipelines_map
        |> Map.update(pipeline_name, [channel], fn channel_list ->
          channel_list ++ [channel]
            |> Enum.sort
            |> Enum.uniq
        end)
        |> Map.update(worker_name, [channel], fn channel_list ->
          channel_list ++ [channel]
            |> Enum.sort
            |> Enum.uniq
        end)
    end)
  end

  defp do_add_metrics_channel_to_app_config(app_config,  "node-ingress-egress-by-pipeline" = category, channel) do
    update_in(app_config, ["metrics", category], fn workers_map ->
      [_pipeline_name, worker_name] = String.split(channel, "*")
      Map.update(workers_map, worker_name, [channel], fn channel_list ->
        channel_list ++ [channel]
          |> Enum.sort
          |> Enum.uniq
      end)
    end)
  end

  defp do_add_metrics_channel_to_app_config(app_config, category, channel) do
    update_in(app_config, ["metrics", category], fn channel_list ->
      channel_list ++ [channel]
        |> Enum.sort
        |> Enum.uniq
    end)
  end

  defp do_add_pipeline_computation_to_app_config(app_config, pipeline_name, _computation_name, channel) do
    update_in(app_config, ["metrics", "pipeline-computations"], fn pipeline_map ->
      Map.update(pipeline_map, pipeline_name, [channel], fn channel_list ->
        channel_list ++ [channel]
          |> Enum.sort
          |> Enum.uniq
      end)
    end)
  end

  defp get_table_keys(tid) do
    keys(tid)
  end

  defp keys(tid) do
    firstKey = :ets.first(tid)
    keys(tid, firstKey, [firstKey])
  end

  defp keys(_tid, :"$end_of_table", [:"$end_of_table" | tableKeys]) do
    tableKeys
  end

  defp keys(tid, currentKey, tableKeys) do
    nextKey = :ets.next(tid, currentKey)
    keys(tid, nextKey, [nextKey | tableKeys])
  end
end
