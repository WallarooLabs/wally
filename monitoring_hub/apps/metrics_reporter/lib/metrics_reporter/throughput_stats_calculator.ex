defmodule MetricsReporter.ThroughputStatsCalculator do

  def calculate_throughput_stats(throughput_msgs) do
    throughputs_list = throughput_msgs
      |> Enum.reduce([], &(List.insert_at(&2, -1, &1["total_throughput"])))
    {min, max} = Enum.min_max(throughputs_list)
    med = median(throughputs_list)
    generate_throughput_stats(min, med, max)
  end

  defp generate_throughput_stats(min, med, max) do
    %{"min" => min, "med" => med, "max" => max}
  end

	defp median(list) do
    sorted = Enum.sort(list)
    length = Enum.count(sorted)
    mid = div(length, 2)
    rem = rem(length, 2)
    (Enum.at(sorted, mid) + Enum.at(sorted, mid + rem - 1)) / 2 
  end
  
end