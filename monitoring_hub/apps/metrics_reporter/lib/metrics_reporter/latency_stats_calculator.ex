defmodule MetricsReporter.LatencyStatsCalculator do

  def calculate_latency_percentage_bins_data(latency_bins_list, expected_latency_bins) do
    time_sorted_latency_bins_list = time_sort_latency_bins_list(latency_bins_list)
    aggregated_latency_bins_data = aggregate_latency_bins_data(time_sorted_latency_bins_list)
    total_count = calculate_latency_bins_total(aggregated_latency_bins_data)
    do_calculate_latency_percentage_bins_data(aggregated_latency_bins_data, expected_latency_bins, total_count)
  end

  def calculate_cumulative_latency_percentage_bins_data(latency_percentage_bins_data) do
      sorted_keys = Map.keys(latency_percentage_bins_data)
        |> Enum.sort(&(String.to_integer(&1)< String.to_integer(&2)))

    {_, cumulative_latency_percentage_bins_data} = sorted_keys
      |> Enum.reduce({0, %{}}, fn key, {cumulative_percentage, cumulative_latency_percentage_bins_data} ->
        val = Map.get(latency_percentage_bins_data, key)
        cumulative_percentage = calculate_cumulative_percentage(val, cumulative_percentage)
        cumulative_latency_percentage_bins_data = Map.put(cumulative_latency_percentage_bins_data, key, cumulative_percentage)
        {cumulative_percentage, cumulative_latency_percentage_bins_data}
      end)
      cumulative_latency_percentage_bins_data
  end

  defp aggregate_latency_bins_data(latency_bins_list) do
    latency_bins_list
      |> Enum.reduce(%{}, &Map.merge(&1["latency_bins"], &2, fn _k, v1, v2 -> v1 + v2 end))
  end

  def get_empty_latency_percentage_bins_data do
    0..64 |> Enum.reduce(%{}, fn(pow, map) -> Map.put(map, to_string(pow), 0) end)
  end

  defp get_empty_latency_percentage_bins_data(expected_latency_bins) do
    Map.new(expected_latency_bins, & {&1, 0})
  end

  defp get_percentiles do
    ["50.0", "95.0", "99.0", "99.9", "99.99"]
  end

  def calculate_latency_percentile_bin_stats(cumulative_latency_percentage_bins_msg) do
    sorted_bin_keys = Map.keys(cumulative_latency_percentage_bins_msg)
      |> Enum.sort(&(String.to_integer(&1)< String.to_integer(&2)))
    _latency_percent_bin_stats = get_percentiles()
      |> Enum.reduce(%{}, fn percentile, percentile_map ->
        bin = Enum.reduce_while(sorted_bin_keys, 0, fn bin, _acc ->
          percentage_at_bin = cumulative_latency_percentage_bins_msg[bin]
          if String.to_float(percentile) > percentage_at_bin do
            {:cont, Enum.max_by(sorted_bin_keys, fn bin ->
              String.to_integer(bin)
            end)}
          else
            {:halt, bin}
          end
        end)
        Map.put(percentile_map, percentile, bin)
      end)
  end

  def generate_empty_latency_percentile_bin_stats do
    get_percentiles() |>
      Enum.reduce(%{}, fn percentile, percentile_map ->
        Map.put(percentile_map, percentile, "0")
      end)
  end

  defp calculate_latency_bins_total(latency_bins_data) do
    Map.keys(latency_bins_data)
      |> Enum.reduce(0, &(latency_bins_data[&1] + &2))
  end

  defp do_calculate_latency_percentage_bins_data(aggregated_latency_bins_data, expected_latency_bins, total_count) do
      sorted_keys = Map.keys(aggregated_latency_bins_data)
        |> Enum.sort(&(String.to_integer(&1) < String.to_integer(&2)))

      {_, aggregated_map} =
        expected_latency_bins
          |> Enum.sort(&(String.to_integer(&1) < String.to_integer(&2)))
          |>  Enum.reduce({sorted_keys, %{}}, fn(bin, {keys_list, acc_map}) ->
                {acc_count, updated_keys_list} =
                  Enum.reduce_while(keys_list, {0, keys_list}, fn (key, {acc, remaining_keys}) ->
                    if String.to_integer(key) <= String.to_integer(bin) do
                      {:cont, {acc + Map.get(aggregated_latency_bins_data, key), List.delete(remaining_keys, key)}}
                    else
                      {:halt, {acc, remaining_keys}}
                    end
                  end)
                {updated_keys_list, Map.put(acc_map, bin, acc_count)}
              end)

      map = get_empty_latency_percentage_bins_data(expected_latency_bins)
        |> Map.merge(aggregated_map, fn _k, _v1, v2 ->
          calculate_percentile(v2, total_count)
        end)
      map
        |> Map.new(fn {k, v} ->
          pow_key = :math.pow(2, String.to_integer(k)) |> round |> to_string
          {pow_key, v} end)
  end

  defp time_sort_latency_bins_list(latency_bins_list) do
    latency_bins_list
    |> Enum.sort(&(&1["time"] < &2["time"]))
  end

  defp calculate_percentile(value, total_count) do
    if total_count == 0 do
      0
    else
      Float.round((value / total_count) * 100, 4)
    end
  end

  defp calculate_cumulative_percentage(value, cumulative_percentage) do
    cond do
      (value + cumulative_percentage >= 100) ->
        100
      (value + cumulative_percentage == 0) ->
        0
      true ->
        Float.round(value + cumulative_percentage, 4)
    end
  end

end
