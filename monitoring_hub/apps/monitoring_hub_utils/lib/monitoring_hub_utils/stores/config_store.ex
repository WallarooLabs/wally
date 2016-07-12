defmodule MonitoringHubUtils.Stores.ConfigStore do
  use GenServer
  require Logger

  ## Client API

  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_client_config(client_name) do
    GenServer.call(__MODULE__, {:get_client_config, client_name})
  end

  def store_client_config(client_name, client_config) do
    GenServer.call(__MODULE__, {:store_client_config, [client_name: client_name, client_config: client_config]})
  end

  ## Server Callbacks
  def init([]) do
    tid = :ets.new(:config_store, [:named_table, :set])
    {:ok, %{tid: tid}}
  end

  def handle_call({:get_client_config, client_name}, _from, %{tid: tid} = state) do
    result = case :ets.lookup(tid, client_name) do
      [{^client_name, client_config}] ->
        {:ok, client_config}
      [] ->
        {:error, "client config not found for: #{client_name}"}
      end
    {:reply, result, state}
  end

  def handle_call({:store_client_config, [client_name: client_name, client_config: client_config]}, _from, %{tid: tid} = state) do
    true = :ets.insert(tid, {client_name, client_config})
    {:reply, {:ok, client_config}, state}
  end
end