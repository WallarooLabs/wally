# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
# RECURSE_SUBMAKEFILES := false

TOPOLOGY_LAYOUT_VALIDATOR_PATH = $(wallaroo_path)/testing/correctness/topology_layouts/apps/validator
SINGLE_STREAM_PARTITIONED_STATE_PARTITION_STATELESS_APP_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

test-testing-correctness-topology_layouts-apps-single_stream-partitioned-state_partition_stateless_app: build-testing-correctness-topology_layouts-apps-validator

test-testing-correctness-topology_layouts-apps-single_stream-partitioned-state_partition_stateless_app: single_stream_partitioned_state_partition_stateless_app_test

single_stream_partitioned_state_partition_stateless_app_test:
	cd $(SINGLE_STREAM_PARTITIONED_STATE_PARTITION_STATELESS_APP_PATH) && \
	integration_test --framed-file-sender ../../../data_gen/_test.msg \
	--validation-cmd '$(TOPOLOGY_LAYOUT_VALIDATOR_PATH)/validator -e ../../../data_gen/_expected.msg -i' \
	--output 'received.txt' \
	--giles-mode \
	--log-level error \
	--command './state_partition_stateless_app' \
	--sink-expect 100

# Multi-worker tests currently fail:
# Error initializing local topology
# This should never happen: failure in lib/wallaroo/initialization/local_topology.pony at line 1236
# See Issue: 947

#test-testing-correctness-topology_layouts-apps-single_stream-partitioned-state_partition_stateless_app: two_worker_single_stream_partitioned_state_partition_stateless_app_test

two_worker_single_stream_partitioned_state_partition_stateless_app_test:
	cd $(SINGLE_STREAM_PARTITIONED_STATE_PARTITION_STATELESS_APP_PATH) && \
	integration_test --framed-file-sender ../../../data_gen/_test.msg \
	--workers 2 \
	--validation-cmd '$(TOPOLOGY_LAYOUT_VALIDATOR_PATH)/validator -e ../../../data_gen/_expected.msg -i' \
	--output 'received.txt' \
	--giles-mode \
	--log-level error \
	--command './state_partition_stateless_app' \
	--sink-expect 100

#test-testing-correctness-topology_layouts-apps-single_stream-partitioned-state_partition_stateless_app: three_worker_single_stream_partitioned_state_partition_stateless_app_test

three_worker_single_stream_partitioned_state_partition_stateless_app_test:
	cd $(SINGLE_STREAM_PARTITIONED_STATE_PARTITION_STATELESS_APP_PATH) && \
	integration_test --framed-file-sender ../../../data_gen/_test.msg \
	--workers 3 \
	--validation-cmd '$(TOPOLOGY_LAYOUT_VALIDATOR_PATH)/validator -e ../../../data_gen/_expected.msg -i' \
	--output 'received.txt' \
	--giles-mode \
	--log-level error \
	--command './state_partition_stateless_app' \
	--sink-expect 100

# end of prevent rules from being evaluated/included multiple times
endif
