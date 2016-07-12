defmodule MarketSpreadReports.RejectedOrdersStore do
  use GenServer

  def start_link do
    {:ok, _pid} = GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def store_rejected_order_msgs(rejected_order_msgs) do
    GenServer.call(__MODULE__, {:store_rejected_order_msgs, rejected_order_msgs})
  end

  def get_rejected_order_msgs do
    GenServer.call(__MODULE__, :get_rejected_order_msgs)
  end
 
  def init([]) do
    tid = :ets.new(:rejected_orders_store, [:named_table, :ordered_set])
    {:ok, %{tid: tid}}
  end

  def handle_call({:store_rejected_order_msgs, rejected_order_msgs}, _from,
    %{tid: tid} = state) do
    updated_rejected_order_msgs = rejected_order_msgs
      |> Enum.map(fn(rejected_order_msg) ->
        order_id = rejected_order_msg["order_id"]
        unix_timestamp = rejected_order_msg["timestamp"]
        updated_rejected_order_msg = Map.put(rejected_order_msg, "timestamp", unix_timestamp)
        {order_id, updated_rejected_order_msg}
      end)
    true = :ets.insert(tid, updated_rejected_order_msgs)
    keyless_rejected_order_msgs = updated_rejected_order_msgs
      |> Enum.map(fn {_k, rejected_order_msg} ->rejected_order_msg end)
    {:reply, {:ok, keyless_rejected_order_msgs}, state}
  end

  def handle_call(:get_rejected_order_msgs, _from, %{tid: tid} = state) do

    rejected_order_msgs = :ets.match(tid, :"$1")
      |> Enum.map(fn [{_timestamp, rejected_order_msg}] -> rejected_order_msg end)
    {:reply, {:ok, rejected_order_msgs}, state}
  end

end