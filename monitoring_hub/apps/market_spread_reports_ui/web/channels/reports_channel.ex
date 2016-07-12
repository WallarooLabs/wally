defmodule MarketSpreadReportsUI.ReportsChannel do
	use Phoenix.Channel
  require Logger

  alias MarketSpreadReports.{RejectedOrdersStore, ClientOrderSummaryStore}

  def join("reports:market-spread", _message, socket) do
    if (socket.transport_name != :tcp), do: send(self, :after_join)
    {:ok, socket}
  end

  def handle_in("rejected-orders", rejected_order_msgs, socket) do
    {:ok, updated_rejected_order_msgs} = RejectedOrdersStore.store_rejected_order_msgs(rejected_order_msgs)
    data = %{rejected_orders: updated_rejected_order_msgs}
    broadcast! socket, "rejected-order-msgs", data
    {:reply, :ok, socket}
  end

  def handle_in("client-order-summaries", client_order_summary_msgs, socket) do
    {:ok, updated_client_order_summary_msgs} = ClientOrderSummaryStore.store_client_order_summary_msgs(client_order_summary_msgs)
    data = %{client_order_summary_msgs: updated_client_order_summary_msgs}
    broadcast! socket, "client-order-summary-msgs", data
    {:reply, :ok, socket}
  end

  def handle_info(:after_join, socket) do
    push_rejected_orders(socket)
    push_client_order_summaries(socket)
    {:noreply, socket}
  end

  defp push_rejected_orders(socket) do
    {:ok, rejected_order_msgs} = RejectedOrdersStore.get_rejected_order_msgs
    data = %{rejected_orders: rejected_order_msgs}
    push socket, "rejected-order-msgs", data
  end

  defp push_client_order_summaries(socket) do
    {:ok, client_order_summary_msgs} = ClientOrderSummaryStore.get_client_order_summary_msgs
    data = %{client_order_summary_msgs: client_order_summary_msgs}
    push socket, "client-order-summary-msgs", data
  end
end