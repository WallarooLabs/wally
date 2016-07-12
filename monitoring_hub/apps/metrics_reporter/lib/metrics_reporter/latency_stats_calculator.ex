defmodule MetricsReporter.LatencyStatsCalculator do

  def calculate_latency_percentage_bins_data(latency_bins_list) do
    time_sorted_latency_bins_list = time_sort_latency_bins_list(latency_bins_list)
    aggregated_latency_bins_data = aggregate_latency_bins_data(time_sorted_latency_bins_list)
    total_count = calculate_latency_bins_total(aggregated_latency_bins_data)
    aggregated_latency_percentage_bins_data = do_calculate_latency_percentage_bins_data(aggregated_latency_bins_data, total_count)
  end

  def calculate_cumalative_latency_percentage_bins_data(latency_percentage_bins_data) do
    {_, cumalative_latency_percentage_bins_data} = latency_percentage_bins_data
      |> Enum.reduce({0, %{}}, fn {key, val}, {cumalative_percentage, cumalative_latency_percentage_bins_data} ->
        cumalative_percentage = calculate_cumalative_percentage(val, cumalative_percentage)
        cumalative_latency_percentage_bins_data = Map.put(cumalative_latency_percentage_bins_data, key, cumalative_percentage)
        {cumalative_percentage, cumalative_latency_percentage_bins_data}
      end)
      cumalative_latency_percentage_bins_data
  end

  defp aggregate_latency_bins_data(latency_bins_list) do
    latency_bins_list
      |> Enum.reduce([], fn latency_bins_data, list ->
        fixed_latency_bins_data = fix_latency_bins_keys(latency_bins_data)
        List.insert_at(list, -1, fixed_latency_bins_data)
      end)
      |> Enum.reduce(%{}, &Map.merge(&1["latency_bins"], &2, fn _k, v1, v2 -> v1 + v2 end))
  end

  def get_empty_latency_percentage_bins_data do
    %{
      "0.000001" => 0, "0.00001" => 0, "0.0001" => 0, "0.001" => 0, "0.01" => 0,
      "0.1" => 0, "1" => 0, "10" => 0, "100.0" => 0
    }
  end

  defp get_percentiles do
    ["50.0", "75.0", "90.0", "99.0", "99.9"]
  end

  def calculate_latency_percentile_bin_stats(cumalative_latency_percentage_bins_msg) do
    bin_keys = Map.keys(cumalative_latency_percentage_bins_msg)
    latency_percent_bin_stats = get_percentiles
      |> Enum.reduce(%{}, fn percentile, percentile_map ->
        bin = Enum.reduce_while(bin_keys, 0, fn bin, acc ->
          percentage_at_bin = cumalative_latency_percentage_bins_msg[bin]
          if String.to_float(percentile) > percentage_at_bin, do: {:cont, Enum.max(bin_keys)}, else: {:halt, bin}
        end)
        Map.put(percentile_map, percentile, bin)
      end)
  end

  defp calculate_latency_bins_total(latency_bins_data) do
    Map.keys(latency_bins_data)
      |> Enum.reduce(0, &(latency_bins_data[&1] + &2))
  end

  defp do_calculate_latency_percentage_bins_data(aggregated_latency_bins_data, total_count) do
    get_empty_latency_percentage_bins_data
      |> Map.merge(aggregated_latency_bins_data, fn _k, _v1, v2 ->
        calculate_percentile(v2, total_count)
      end)
  end

  defp time_sort_latency_bins_list(latency_bins_list) do
    latency_bins_list
    |> Enum.sort(&(&1["time"] < &2["time"]))
  end

  defp calculate_percentile(value, total_count) do
    if total_count == 0 do
      0
    else
      Float.round((value / total_count) * 100, 2)
    end
  end

  defp calculate_cumalative_percentage(value, cumalative_percentage) do
    cond do
      (value + cumalative_percentage >= 100) ->
        100
      (value + cumalative_percentage == 0) ->
        0
      true ->
        Float.round(value + cumalative_percentage, 2)
    end
  end

  defp replace_key(map, from, to) do
   with %{^from => value} <- map do
     map |> Map.delete(from) |> Map.put(to, value)
   end 
  end

  defp fix_latency_bins_keys(latency_bins_data) do
    latency_bins = latency_bins_data["latency_bins"]
    fixed_latency_bins = latency_bins
      |> replace_key("1e-05", "0.00001")
      |> replace_key("1e-06", "0.000001")
      |> replace_key("overflow", "100.0")
    Map.put(latency_bins_data, "latency_bins", fixed_latency_bins)
  end
end