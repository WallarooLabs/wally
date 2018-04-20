defmodule MetricsReporter.LatencyStatsCalculator.CumulativePercentage do
  import MetricsReporter.LatencyStatsCalculator, only: [sorted_keys_by_numeric_value: 1]

  def calculate(bins) do
    bins
    |> sorted_keys_by_numeric_value()
    |> Enum.reduce({0, %{}}, fn key, {percentage, acc} ->
      new_percentage = bins
      |> Map.get(key)
      |> cumulative_percentage(percentage)

      {new_percentage, Map.put(acc, key, new_percentage)}
    end)
    |> elem(1)
  end

  defp cumulative_percentage(value, accumulated) when value + accumulated >= 100, do: 100
  defp cumulative_percentage(value, accumulated) when value + accumulated == 0, do: 0
  defp cumulative_percentage(value, accumulated), do: Float.round(value + accumulated, 4)
end
