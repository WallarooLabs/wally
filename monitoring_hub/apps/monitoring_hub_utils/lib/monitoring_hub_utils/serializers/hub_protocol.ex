defmodule MonitoringHubUtils.Serializers.HubProtocol do
  # 8 (64bit int) * 65 == 52o
  @latency_65_bins 520

  # due to not sending data back to Wallaroo, encoding defaults to 1
  def encode(_value) do
    << 1 >>
  end

  def encode_to_iodata!(_value) do
    << 1 >>
  end

  def decode(data) do
    error_msg = decode_error_msg()
    case decode!(data) do
      ^error_msg ->
        {:error, decode_error_msg()}
      decoded_msg ->
        {:ok, decoded_msg}
    end
  end

  def decode!(<< 1 :: size(8) >> = _iodata) do
    %{
      "path" => "/socket/tcp",
      "params" => nil
    }
  end

  def decode!(<< 2 :: size(8), topic_size :: size(32),
    topic :: binary-size(topic_size) >> = _iodata)
  do
    %{
      "event" => "phx_join",
      "topic" => topic,
      "ref" => nil,
      "payload" => %{}
    }
  end

  def decode!(<< 2 :: size(8), topic_size :: size(32),
    topic :: binary-size(topic_size), worker_name_size :: size(32),
    worker_name :: binary-size(worker_name_size) >> = _iodata)
  do
    %{
      "event" => "phx_join",
      "topic" => topic,
      "ref" => nil,
      "payload" => %{
        "worker_name" => worker_name
      }
    }
  end

  def decode!(<< 3 :: size(8), event_size :: size(32),
    event :: binary-size(event_size), topic_size :: size(32),
    topic :: binary-size(topic_size), _payload_size :: size(32),
    payload :: binary>> = _iodata)
  do
    %{
      "event" => event,
      "topic" => topic,
      "ref" => nil,
      "payload" => payload_decode(payload)
    }
  end

  def decode!(_unknown_data) do
    decode_error_msg()
  end

  # 4-header : 1-side-U8 : 4-client_id-U32 : 6-order_id-String :
  # 4-symbol-String : 8-order_qty-F64 : 8-price-F64 : 8-bid-F64 :
  # 8-offer-F64 : 8-timestamp-U64

  defp payload_decode(<< _header :: size(32), side :: unsigned-integer-size(8),
    client_id :: unsigned-integer-size(32), order_id :: bitstring-size(48),
    symbol :: bitstring-size(32), order_qty :: float-size(64),
    price :: float-size(64), bid :: float-size(64), offer :: float-size(64),
    timestamp :: unsigned-integer-size(64) >>)
  do

    side_string = if side == 1, do: "BUY", else: "SELL"
    %{
      "side" => side_string,
      "client_id" => client_id,
      "order_id" => order_id,
      "symbol" => symbol,
      "order_qty" => order_qty,
      "price" => price,
      "bid" => bid,
      "offer" => offer,
      "timestamp" => round(timestamp / 1000000000)
    }
  end

  # (4)-[header]-U32 :
  # (4)-[name-size]-U32 : (name-size)-[name]-String :
  # (4)-[category-size]-U32 : (category-size)-[category]-String :
  # (4)-[worker-name-size]-U32 : (worker-name-size)-[worker-name]-String :
  # (4)-[pipeline-name-size]-U32 : (pipeline-name-size)-[pipeline-name]-String :
  # (2)-[id]-U16
  # [65 8-byte latency values as U64s] :
  # (8)-period-U64 : 8-period_ends_at_timestamp-U64

  defp payload_decode(<< _header :: size(32), name_size :: size(32),
    name :: binary-size(name_size), _category_size :: size(32),
    "computation", worker_name_size :: size(32),
    worker_name :: binary-size(worker_name_size),
    pipeline_name_size :: size(32), pipeline_name :: binary-size(pipeline_name_size),
    id :: size(16),
    bins :: binary-size(@latency_65_bins),
    min_val :: unsigned-integer-size(64),
    max_val :: unsigned-integer-size(64),
    period :: unsigned-integer-size(64),
    timestamp :: unsigned-integer-size(64),
    >>)
  do
    %{
      "name" => pipeline_name <> "@" <> worker_name <> ":" <> name,
      "category" => "computation",
      "worker" => worker_name,
      "pipeline" => pipeline_name,
      "id" => to_string(id),
      "latency_list" =>
        (for <<v::unsigned-integer-size(64) <- bins >>, do: v),
      "min" => min_val,
      "max" => max_val,
      "period" => round(period / 1000000000),
      "timestamp" => round(timestamp / 1000000000)
    }
  end

  defp payload_decode(<< _header :: size(32), name_size :: size(32),
    _name :: binary-size(name_size), _category_size :: size(32),
    "start-to-end", worker_name_size :: size(32),
    worker_name :: binary-size(worker_name_size),
    pipeline_name_size :: size(32), pipeline_name :: binary-size(pipeline_name_size),
    id :: size(16),
    bins :: binary-size(@latency_65_bins),
    min_val :: unsigned-integer-size(64), max_val :: unsigned-integer-size(64),
    period :: unsigned-integer-size(64), timestamp :: unsigned-integer-size(64),
    >>)
  do
    %{
      "name" => pipeline_name <> "@" <> worker_name,
      "category" => "start-to-end",
      "worker" => worker_name,
      "pipeline" => pipeline_name,
      "id" => to_string(id),
      "latency_list" =>
        (for <<v::unsigned-integer-size(64) <- bins >>, do: v),
      "min" => min_val,
      "max" => max_val,
      "period" => round(period / 1000000000),
      "timestamp" => round(timestamp / 1000000000)
    }
  end

  defp payload_decode(<< _header :: size(32), name_size :: size(32),
    _name :: binary-size(name_size), _category_size :: size(32),
    "node-ingress-egress", worker_name_size :: size(32),
    worker_name :: binary-size(worker_name_size),
    pipeline_name_size :: size(32), pipeline_name :: binary-size(pipeline_name_size),
    id :: size(16),
    bins :: binary-size(@latency_65_bins),
    min_val :: unsigned-integer-size(64), max_val :: unsigned-integer-size(64),
    period :: unsigned-integer-size(64), timestamp :: unsigned-integer-size(64),
    >>)
  do
    %{
      "name" => pipeline_name <> "*" <> worker_name,
      "category" => "node-ingress-egress",
      "worker" => worker_name,
      "pipeline" => pipeline_name,
      "id" => to_string(id),
      "latency_list" =>
        (for <<v::unsigned-integer-size(64) <- bins >>, do: v),
      "min" => min_val,
      "max" => max_val,
      "period" => round(period / 1000000000),
      "timestamp" => round(timestamp / 1000000000)
    }
  end

  defp payload_decode(<< _header :: size(32), name_size :: size(32),
    name :: binary-size(name_size), category_size :: size(32),
    category :: binary-size(category_size), worker_name_size :: size(32),
    worker_name :: binary-size(worker_name_size),
    pipeline_name_size :: size(32), pipeline_name :: binary-size(pipeline_name_size),
    id :: size(16),
    bins :: binary-size(@latency_65_bins),
    min_val :: unsigned-integer-size(64), max_val :: unsigned-integer-size(64),
    period :: unsigned-integer-size(64), timestamp :: unsigned-integer-size(64),
    >>)
  do
    %{
      "name" => name,
      "category" => category,
      "worker" => worker_name,
      "pipeline" => pipeline_name,
      "id" => to_string(id),
      "latency_list" =>
        (for <<v::unsigned-integer-size(64) <- bins >>, do: v),
      "min" => min_val,
      "max" => max_val,
      "period" => round(period / 1000000000),
      "timestamp" => round(timestamp / 1000000000)
    }
  end

  defp decode_error_msg do
    "Unable to decode message using #{__MODULE__}"
  end


end
