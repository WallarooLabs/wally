defmodule MetricsReporterUI.MetricsSocket do
	use Phoenix.Socket

  ## Channels
  channel "applications", MetricsReporterUI.ApplicationsChannel
  channel "metrics:*", MetricsReporterUI.MetricsChannel
  channel "app-config:*", MetricsReporterUI.AppConfigChannel
  channel "step:*", MetricsReporterUI.StepChannel
  channel "ingress-egress:*", MetricsReporterUI.IngressEgressChannel
  channel "source-sink:*", MetricsReporterUI.SourceSinkChannel
  channel "computation:*", MetricsReporterUI.ComputationChannel
  channel "start-to-end:*", MetricsReporterUI.StartEndChannel
  channel "node-ingress-egress:*", MetricsReporterUI.NodeIngressEgressChannel
  channel "pipeline:*", MetricsReporterUI.PipelineChannel
  channel "pipeline-ingestion:*", MetricsReporterUI.PipelineIngestionChannel
  channel "computation-by-worker:*", MetricsReporterUI.ComputationByWorkerChannel
  channel "node-ingress-egress-by-pipeline:*", MetricsReporterUI.NodeIngressEgressByPipelineChannel
  channel "start-to-end-by-worker:*", MetricsReporterUI.StartEndByWorkerChannel

  transport :websocket, Phoenix.Transports.WebSocket
  transport :longpoll, Phoenix.Transports.LongPoll
  transport :tcp, PhoenixTCP.Transports.TCP,
    timeout: :infinity,
    serializer: [{MonitoringHubUtils.Serializers.TCPSerializer, "~> 1.0.0"}],
    tcp_server: MonitoringHubUtils.TCPServer

  # Socket params are passed from the client and can
  # be used to verify and authenticate a user. After
  # verification, you can put default assigns into
  # the socket that will be set for all channels, ie
  #
  #     {:ok, assign(socket, :user_id, verified_user_id)}
  #
  # To deny connection, return `:error`.
  #
  # See `Phoenix.Token` documentation for examples in
  # performing token verification on connect.
  def connect(_params, socket) do
    {:ok, socket}
  end

  # Socket id's are topics that allow you to identify all sockets for a given user:
  #
  #     def id(socket), do: "users_socket:#{socket.assigns.user_id}"
  #
  # Would allow you to broadcast a "disconnect" event and terminate
  # all active sockets and channels for a given user:
  #
  #     MonitoringHub.Endpoint.broadcast("users_socket:#{user.id}", "disconnect", %{})
  #
  # Returning `nil` makes this socket anonymous.
  def id(_socket), do: nil

end
