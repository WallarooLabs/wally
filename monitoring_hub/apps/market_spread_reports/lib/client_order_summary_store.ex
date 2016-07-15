defmodule MarketSpreadReports.ClientOrderSummaryStore do
  use GenServer

  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def store_client_order_summary_msgs(client_order_summary_msgs) do
    GenServer.call(__MODULE__, {:store_client_order_summary_msgs, client_order_summary_msgs})
  end

  def get_client_order_summary_msgs do
    GenServer.call(__MODULE__, :get_client_order_summary_msgs)
  end

  def init([]) do
    tid = :ets.new(:client_order_summary_store, [:named_table, :set])
    {:ok, %{tid: tid}}
  end

  def handle_call({:store_client_order_summary_msgs, client_order_summary_msgs}, _from,
    %{tid: tid} = state) do
    updated_client_order_summary_msgs = client_order_summary_msgs
      |> Enum.map(fn client_order_summary_msg ->
        client_id = client_order_summary_msg["client_id"]
        updated_client_order_summary_msg = update_client_order_summary_msg(client_order_summary_msg)
        {client_id, updated_client_order_summary_msg}
      end)
    true = :ets.insert(tid, updated_client_order_summary_msgs)
    keyless_updated_client_order_summary_msgs = updated_client_order_summary_msgs
      |> Enum.map(fn {_k, client_order_summary_msg} -> client_order_summary_msg end)
    {:reply, {:ok, keyless_updated_client_order_summary_msgs}, state}   
  end

  def handle_call(:get_client_order_summary_msgs, _from, %{tid: tid} = state) do
    client_order_summary_msgs = :ets.match(tid, :"$1")
      |> Enum.map(fn [{_client_id, client_order_summary_msg}] -> client_order_summary_msg end)
    {:reply, {:ok, client_order_summary_msgs}, state}
  end

  defp update_client_order_summary_msg(client_order_summary_msg) do
    total_orders = client_order_summary_msg["total_orders"]
    rejected_count = client_order_summary_msg["rejected_count"]
    rejected_pct = Float.round(rejected_count / total_orders * 100, 4)
    Map.put(client_order_summary_msg, "rejected_pct", rejected_pct)
  end
end