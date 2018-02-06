defmodule MonitoringHubUtils.Helpers do
	def create_channel_name(category, app_name, pipeline_key) do
		category <> ":" <> app_name <> "||" <> pipeline_key
	end
end
