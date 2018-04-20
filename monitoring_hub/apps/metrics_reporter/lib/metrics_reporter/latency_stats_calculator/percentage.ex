defmodule MetricsReporter.LatencyStatsCalculator.Percentage do
  import String, only: [to_integer: 1]
  import MetricsReporter.LatencyStatsCalculator, only: [sorted_keys_by_numeric_value: 1]

  def calculate(bins, keys) do
    bins
    |> aggregate()
    |> do_calculate(keys)
  end

  def default_data(keys), do: Map.new(keys, &({&1, 0}))

  defp aggregate(bins_list) do
    bins_list
    |> Enum.map(&(&1["latency_bins"]))
    |> Enum.reduce(%{}, &(Map.merge(&1, &2, fn(_k, v1, v2) -> v1 + v2 end)))
  end

  defp do_calculate(aggregated_bin, keys) do
    aggregated_bin
    |> build_aggregated_map(sorted_keys_by_numeric_value(keys))
    |> percentilize_vals(keys, totalize(aggregated_bin))
  end

  defp build_aggregated_map(aggregated_bin, expected_keys) do
    aggregated_keys = sorted_keys_by_numeric_value(aggregated_bin)

    expected_keys
    |> Enum.reduce({aggregated_keys, %{}}, &(reductor(&1, &2, aggregated_bin)))
    |> elem(1)
  end

  defp reductor(bin, {keys_list, acc_map} , aggregated_bins) do
    {sum, updated_keys_list} = aggregate_at_key_up_to_bin_sum(keys_list, bin, aggregated_bins)
    {updated_keys_list, Map.put(acc_map, bin, sum)}
  end

  defp aggregate_at_key_up_to_bin_sum(keys, bin, aggregated_bins) do
    Enum.reduce_while(keys, {0, keys}, fn (key, {acc, remaining_keys}) ->
      if to_integer(key) <= to_integer(bin) do
        {:cont, {acc + Map.get(aggregated_bins, key), List.delete(remaining_keys, key)}}
      else
        {:halt, {acc, remaining_keys}}
      end
    end)
  end

  defp percentilize_vals(map, keys, total) do
    keys
    |> default_data()
    |> Map.merge(map, fn(_, _, v) -> calculate_percentile(v, total) end)
    |> Map.new(fn {k, v} -> {square_and_stringify(k), v} end)
  end

  defp totalize(bins), do: Map.values(bins) |> Enum.sum()

  defp square_and_stringify(k), do: :math.pow(2, to_integer(k)) |> round() |> to_string()

  defp calculate_percentile(_, 0), do: 0
  defp calculate_percentile(value, count), do: Float.round((value / count) * 100, 4)
end
