defmodule MetricsReporter.LatencyStatsCalculator do

  import String, only: [to_integer: 1]

  @default_bins_keys Enum.map((0..64), &to_string/1)

  alias MetricsReporter.LatencyStatsCalculator.{CumulativePercentage, Percentage, Percentile}

  defdelegate calculate_latency_percentage_bins_data(bins_list, expected_bins), to: Percentage, as: :calculate
  defdelegate get_empty_latency_percentage_bins_data(keys \\ @default_bins_keys), to: Percentage, as: :default_data
  defdelegate calculate_cumulative_latency_percentage_bins_data(bins), to: CumulativePercentage, as: :calculate
  defdelegate calculate_latency_percentile_bin_stats(bins_msg), to: Percentile, as: :calculate
  defdelegate generate_empty_latency_percentile_bin_stats, to: Percentile, as: :default_data

  def sorted_keys_by_numeric_value(map) when is_map(map), do: sorted_keys_by_numeric_value(Map.keys(map))
  def sorted_keys_by_numeric_value(list) when is_list(list), do: Enum.sort(list, &(to_integer(&1) < to_integer(&2)))
end
