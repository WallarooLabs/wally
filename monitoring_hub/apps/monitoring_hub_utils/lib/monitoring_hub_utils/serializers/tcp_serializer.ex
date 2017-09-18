defmodule MonitoringHubUtils.Serializers.TCPSerializer do
	@behaviour Phoenix.Transports.Serializer

	alias Phoenix.Socket.Reply
	alias Phoenix.Socket.Message
	alias Phoenix.Socket.Broadcast
	alias MonitoringHubUtils.Serializers.HubProtocol

	@doc """
	Translates a `Phoenix.Socket.Broadcast` into a `Phoenix.Socket.Message`.
	"""
	def fastlane!(%Broadcast{} = msg) do
		{:socket_push, :binary, HubProtocol.encode_to_iodata!(%Message{
			topic: msg.topic,
			event: msg.event,
			payload: msg.payload
		})}
	end

	@doc """
	Encodes a `Phoenix.Socket.Message` struct to Binary data
	"""
	def encode!(%Reply{} = reply) do
		{:socket_push, :binary, HubProtocol.encode_to_iodata!(%Message{
			topic: reply.topic,
			event: "phx_reply",
			ref: reply.ref,
			payload: %{status: reply.status, response: reply.payload}
		})}
	end
	def encode!(%Message{} = msg) do
		{:socket_push, :binary, HubProtocol.encode_to_iodata!(msg)}
	end

	@doc """
	Decodes Binary data into `Phoenix.Socket.Message` struct.
	"""
	def decode!(message, _opts) do
		message
		|> HubProtocol.decode!()
		|> Phoenix.Socket.Message.from_map!()
	end
end
