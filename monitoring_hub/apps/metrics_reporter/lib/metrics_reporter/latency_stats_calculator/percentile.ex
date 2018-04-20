defmodule MetricsReporter.LatencyStatsCalculator.Percentile do
  import String, only: [to_integer: 1, to_float: 1]
  import MetricsReporter.LatencyStatsCalculator, only: [sorted_keys_by_numeric_value: 1]

  @percentiles ["50.0", "95.0", "99.0", "99.9", "99.99"]

  def calculate(bins) do
    Enum.reduce(@percentiles, %{}, &(build_map(&1, &2, bins)))
  end

  defp build_map(percentile, acc, bins) do
    value = value_for_percentile(to_float(percentile), bins)
    Map.put(acc, percentile, value)
  end

  defp value_for_percentile(percentile, bins) do
    bins
    |> Map.to_list()
    |> Enum.sort(&(to_integer(elem(&1, 0)) < to_integer(elem(&2, 0))))
    |> Enum.find(&(percentile <= elem(&1, 1)))
    |> elem(0)
  end

  def default_data, do: Map.new(@percentiles, &({&1, "0"}))
end
