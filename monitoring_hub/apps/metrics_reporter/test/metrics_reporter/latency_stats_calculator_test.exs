defmodule MetricsReporter.LatencyStatsCalculatorTest do
	use ExUnit.Case
	require Logger

	alias MetricsReporter.LatencyStatsCalculator

	setup do
		latency_bins_msg_1 = %{"time" => 1523977525,
		"pipeline_key" => "test",
		"latency_bins" => %{"1" => 100, "10" => 50}
		}
		latency_bins_msg_2 = %{"time" => 1523977526,
		"pipeline_key" => "test",
		"latency_bins" => %{"1" => 50, "10" => 100}
		}
		expected_latency_bins = get_all_bins()
		latency_bins_list = [latency_bins_msg_1, latency_bins_msg_2]
		empty_stats = %{
			"50.0" => "0",
			"95.0" => "0",
			"99.0" => "0",
			"99.9" => "0",
			"99.99" => "0"
			}
		%{expected_latency_bins: expected_latency_bins, latency_bins_list: latency_bins_list, empty_stats: empty_stats}
	end

	defp get_all_bins do
    Enum.reduce(0..64, [], fn bin, list ->
      List.insert_at(list, -1, bin |> to_string)
    end)
  end

	test "it calculates the percentage of the values that fall within each bin for a set of latency bin messages, where the key becomes the previous key to the power of 2", %{latency_bins_list: latency_bins_list, expected_latency_bins: expected_latency_bins} do
		latency_bins_data = LatencyStatsCalculator.calculate_latency_percentage_bins_data(latency_bins_list, expected_latency_bins)
		Enum.each latency_bins_data, fn {bin, percentage} ->
			cond do
				bin == "2" ->
					# verifying that 50% of the total count of messages fall under the "1"/2^1 bin
					percentage == 50.0
				bin == "1024" ->
					# verifying that 50% of the total count of messages fall under the "10"/2^10 bin
					percentage == 50.00
				true ->
					# verifying that 0% of the total count of messages fall under the remaining bins
					percentage == 0.0
			end
		end
	end

	test "it calculates the cumulative percentage for each bin in a map of bin to percentage data", %{latency_bins_list: latency_bins_list, expected_latency_bins: expected_latency_bins} do
		latency_bins_data = LatencyStatsCalculator.calculate_latency_percentage_bins_data(latency_bins_list, expected_latency_bins)
		cumulative_latency_percentage_bins_data = LatencyStatsCalculator.calculate_cumulative_latency_percentage_bins_data(latency_bins_data)
		Enum.each cumulative_latency_percentage_bins_data, fn {bin, cumulative_percentage} ->
			cond do
				String.to_integer(bin) < 2 ->
					# verifying that 0% of the total cumulative count of messages fall under the "0"/2^0 bin
					cumulative_percentage == 0.0
				bin == "2" ->
					# verifying that 50% of the total cumulative count of messages fall in the "1"/2^1 bin
					cumulative_percentage == 50.0
				(String.to_integer(bin) > 2) && (String.to_integer(bin) < 1024) ->
					# verifying that 50% of the total cumulative count of messages fall below the "10"/2^10 bin
					cumulative_percentage == 50.00
				bin == "1024" ->
					# verifying that 100% of the total cumulative count of messages fall in the "10"/2^10 bin
					cumulative_percentage == 100.00
				String.to_integer(bin) > 1024 ->
					# verifying that 100% of the total cumulative count of messages fall above the "10"/2^10 bin
					cumulative_percentage == 0.0
			end
		end
	end

	test "it calculates the latency percentile bin stats based off the cumulative latency percentage bins", %{expected_latency_bins: expected_latency_bins, latency_bins_list: latency_bins_list} do
		latency_bins_data = LatencyStatsCalculator.calculate_latency_percentage_bins_data(latency_bins_list, expected_latency_bins)
		cumulative_latency_percentage_bins_data = LatencyStatsCalculator.calculate_cumulative_latency_percentage_bins_data(latency_bins_data)
		latency_percentile_bin_stats = LatencyStatsCalculator.calculate_latency_percentile_bin_stats(cumulative_latency_percentage_bins_data)
		Enum.each latency_percentile_bin_stats, fn {percentile, bin} ->
			cond do
				percentile == "50.0" ->
					assert bin == "2"
				true ->
					assert bin == "1024"
			end
		end
	end

	test "it generates empty stats for the expected percentiles", %{empty_stats: empty_stats} do
		assert LatencyStatsCalculator.generate_empty_latency_percentile_bin_stats == empty_stats
	end

	test "it generates an empty map with the keys 0..64 as strings and the values as 0" do
		empty_percentage_bins_data = LatencyStatsCalculator.get_empty_latency_percentage_bins_data
		for n <- 0..64 do
			assert empty_percentage_bins_data[to_string(n)] == 0
		end
	end
end
