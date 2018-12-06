defmodule MonitoringHubUtils.Stores.AppConfigStoreTest do
  use ExUnit.Case
  require Logger

  alias MonitoringHubUtils.Stores.AppConfigStore

  setup do
  	AppConfigStore.start_link
  	empty_app_config = %{"metrics" => %{
        "start-to-end" => [],
        "node-ingress-egress" => [],
        "computation" => [],
        "pipeline" => [],
        "computation-by-worker" => %{},
        "start-to-end-by-worker" => %{},
        "node-ingress-egress-by-pipeline" => %{},
        "pipeline-computations" => %{},
        "pipeline-ingestion" => []
      },
      "workers" => []
    }
  	{:ok, empty_app_config: empty_app_config}
  end

  test "it retrieves app names" do
    {:ok, _app_config} = AppConfigStore.get_or_create_app_config "named-app-config"
    {:ok, app_names} = AppConfigStore.get_app_names
    assert Enum.find_value(app_names, fn app_name -> app_name == "named-app-config" end)
  end

  test "it stores an app config", %{empty_app_config: empty_app_config} do
  	test_app_config = Map.put(empty_app_config, "app_name", "test-app")
  	{:ok, ^test_app_config} = AppConfigStore.store_app_config("test-app", test_app_config)
  	{:ok, retrieved_app_config} = AppConfigStore.get_app_config("test-app")
  	assert test_app_config === retrieved_app_config
  end

  test "it gets an app config", %{empty_app_config: empty_app_config} do
  	app_config = Map.put(empty_app_config, "app_name", "app-config")
    {:ok, ^app_config} = AppConfigStore.store_app_config "app-config", app_config
    {:ok, retrieved_app_config} = AppConfigStore.get_app_config "app-config"
    assert app_config == retrieved_app_config
  end

  test "it retrieves or creates an app config", %{empty_app_config: empty_app_config} do
  	existing_app_config = empty_app_config
  		|> Map.put("app_name", "existing-app-config")
  		|> update_in(["metrics", "computation"], fn _ -> ["computation:step1"] end)
    {:ok, ^existing_app_config} = AppConfigStore.store_app_config "existing-app-config", existing_app_config
    {:ok, retrieved_exisiting_app_config} = AppConfigStore.get_or_create_app_config "existing-app-config"

    new_app_config = Map.put(empty_app_config, "app_name", "new-app-config")
    {:ok, created_app_config} = AppConfigStore.get_or_create_app_config "new-app-config"
  	assert retrieved_exisiting_app_config == existing_app_config
    assert created_app_config == new_app_config
  end

  test "it adds a metrics channel to an existing app config" do
    _app_config = AppConfigStore.get_or_create_app_config "metrics-app-config"

    {:ok, _updated_app_config} = AppConfigStore.add_metrics_channel_to_app_config "metrics-app-config", "computation", "step1"
    {:ok, updated_app_config} = AppConfigStore.get_app_config "metrics-app-config"
    assert get_in(updated_app_config, ["metrics", "computation"]) == ["step1"]
  end
end
