defmodule MonitoringHubUtils.TCPServer do
	use GenServer
  require Logger

  @behaviour :ranch_protocol

  def start_link(ref, tcp_socket, tcp_transport, opts \\ []) do
    :proc_lib.start_link(__MODULE__, :init, [ref, tcp_socket, tcp_transport, opts])
  end

  def init(ref, tcp_socket, tcp_transport, opts) do
    :ok = :proc_lib.init_ack({:ok, self()})
    :ok = :ranch.accept_ack(ref)
    :ok = tcp_transport.setopts(tcp_socket, [:binary, active: :once, packet: 4])
    state = %{
      tcp_transport: tcp_transport,
      tcp_socket: tcp_socket,
      handlers: Keyword.fetch!(opts, :handlers),
      serializer: opts[:serializer] || Poison,
    }
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def handle_info({:tcp, tcp_socket, data}, %{handlers: handlers, tcp_transport: tcp_transport, serializer: serializer} = state) do
    case serializer.decode(data) do
      {:ok, %{"path" => path, "params" => params}} ->
        case Map.get(handlers, path) do
          # handler is the server which handles the tcp messages
          # currently there is only one server,
          # module is the transport module
          # opts = {endpoint, socket, transport}
          # endpoint being the endpoint defined in the phx app
          # socket being the socket defined in the phx app
          # transport being the atom defining the transport
          {handler, module, opts} ->
            case module.init(params, opts) do
              {:ok, {module, {opts, timeout}}} ->
                state = %{
                  tcp_transport: tcp_transport,
                  tcp_socket: tcp_socket,
                  handler: handler,
                  transport_module: module,
                  transport_config: opts,
                  timeout: timeout
                }
                :ok = tcp_transport.setopts(tcp_socket, [active: :once])
                Logger.info "Connection successful on TCPServer"
                {:noreply, state, timeout}
              {:error, error_msg} ->
                Logger.warn "Error connecting to TCPServer: #{error_msg}"
                :ok = tcp_transport.setopts(tcp_socket, [active: :once])
                {:noreply, state}
            end
          nil ->
            Logger.warn "No path matches for '#{path}'' on TCPServer"
            :ok = tcp_transport.setopts(tcp_socket, [active: :once])
            {:noreply, state}
        end
      {:error, _error} ->
        Logger.warn "Unable to decode data in #{__MODULE__}'s handle_info() using #{serializer} in TCPServer"
        :ok = tcp_transport.setopts(tcp_socket, [active: :once])
        {:noreply, state}
    end
  end

  def handle_info({:tcp, _tcp_socket, payload},
    %{transport_module: module, transport_config: config} = state) do
    handle_reply state, module.tcp_handle(payload, config)
  end

  def handle_info({:tcp_closed, _tcp_socket},
    %{transport_module: module, transport_config: config} = state) do
    module.tcp_close(config)
    {:stop, :shutdown, state}
  end

  def handle_info({:tcp_closed, _tcp_socket}, state) do
    {:stop, :shutdown, state}
  end

  def handle_info(:timeout, %{transport_module: module, transport_config: config} = state) do
    module.tcp_close(config)
    {:stop, :shutdown, state}
  end

  def handle_info(msg, %{transport_module: module, transport_config: config} = state) do
    handle_reply state, module.tcp_info(msg, config)
  end

  def terminate(_reason, %{transport_module: module, transport_config: config}) do
    module.tcp_close(config)
  end

  def terminate(_reason, _state) do
    :ok
  end

  defp handle_reply(state, {:shutdown, new_config}) do
    new_state = Map.put(state, :transport_config, new_config)
    {:stop, :shutdown, new_state}
  end

  defp handle_reply(%{timeout: timeout, tcp_transport: transport,
    tcp_socket: socket} = state, {:ok, new_config}) do
    new_state = Map.put(state, :transport_config, new_config)
    :ok = transport.setopts(socket, [active: :once])
    {:noreply, new_state, timeout}
  end

  defp handle_reply(%{timeout: timeout, tcp_transport: transport, tcp_socket: socket} = state,
      {:reply, {_encoding, _encoded_payload}, new_config}) do
    :ok = transport.setopts(socket, [active: :once])
    new_state = Map.put(state, :transport_config, new_config)
    {:noreply, new_state, timeout}
  end

end
