# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

rules_mk_path := ../../../../../../../rules.mk

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

INTEGRATION_PATH = $(buffy_path)/testing/tools
INTEGRATION_BIN_PATH = $(INTEGRATION_PATH)/integration
TOPOLOGY_LAYOUT_VALIDATOR_PATH = $(buffy_path)/testing/topology_layouts/apps/validator
SINGLE_STREAM_PARTITIONED_UNCOALESCED_STATELESS_STATE_PARTITION_STATELESS_APP_PATH = $(buffy_path)/testing/topology_layouts/apps/single_stream/partitioned/partitioned_uncoalesced/uncoalesced_stateless_state_partition_stateless_app

test-testing-topology_layouts-apps-single_stream-partitioned-partitioned_uncoalesced-uncoalesced_stateless_state_partition_stateless_app-all = build-testing-topology_layouts-apps-single_stream-partitioned-partitioned_uncoalesced-uncoalesced_stateless_state_partition_stateless_app-all single_stream_partitioned_uncoalesced_stateless_state_partition_stateless_app_test

single_stream_partitioned_uncoalesced_stateless_state_partition_stateless_app_test:
	export PYTHONPATH=".:$(INTEGRATION_PATH)" && \
	export PATH="$(PATH):$(INTEGRATION_BIN_PATH)" && \
	cd $(SINGLE_STREAM_PARTITIONED_UNCOALESCED_STATELESS_STATE_PARTITION_STATELESS_APP_PATH) && \
	integration_test --framed-file-sender ../../../../data_gen/_test.msg \
	--validation-cmd '$(TOPOLOGY_LAYOUT_VALIDATOR_PATH)/validator -e ../../../../data_gen/_test.msg -i' \
	--output 'received.txt' \
	--giles-mode \
	--log-level error \
	--command './uncoalesced_stateless_state_partition_stateless_app' \
	--sink-expect 100

# Multi-worker tests currently fail:
#
# Failure on Worker 1:
# DataChannelConnectNotifier : server closed
# BoundaryNotify: closed
# DataChannelConnectNotifier : server closed
# ControlChannelConnectNotifier :worker1: server closed
# Sender error:
# ---
# [Errno 32] Broken pipe
#
# Failure on Worker 2:
# This should never happen: failure in lib/wallaroo/routing/boundary_route.pony at line 52

two_worker_single_stream_partitioned_uncoalesced_stateless_state_partition_stateless_app_test:
	export PYTHONPATH=".:$(INTEGRATION_PATH)" && \
	export PATH="$(PATH):$(INTEGRATION_BIN_PATH)" && \
	cd $(SINGLE_STREAM_PARTITIONED_UNCOALESCED_STATELESS_STATE_PARTITION_STATELESS_APP_PATH) && \
	integration_test --framed-file-sender ../../../../data_gen/_test.msg \
	--workers 2 \
	--validation-cmd '$(TOPOLOGY_LAYOUT_VALIDATOR_PATH)/validator -e ../../../../data_gen/_test.msg -i' \
	--output 'received.txt' \
	--giles-mode \
	--log-level error \
	--command './uncoalesced_stateless_state_partition_stateless_app' \
	--sink-expect 100

three_worker_single_stream_partitioned_uncoalesced_stateless_state_partition_stateless_app_test:
	export PYTHONPATH=".:$(INTEGRATION_PATH)" && \
	export PATH="$(PATH):$(INTEGRATION_BIN_PATH)" && \
	cd $(SINGLE_STREAM_PARTITIONED_UNCOALESCED_STATELESS_STATE_PARTITION_STATELESS_APP_PATH) && \
	integration_test --framed-file-sender ../../../../data_gen/_test.msg \
	--workers 3 \
	--validation-cmd '$(TOPOLOGY_LAYOUT_VALIDATOR_PATH)/validator -e ../../../../data_gen/_test.msg -i' \
	--output 'received.txt' \
	--giles-mode \
	--log-level error \
	--command './uncoalesced_stateless_state_partition_stateless_app' \
	--sink-expect 100


#########################################################################################
#### don't change after this line unless to disable standard rules generation makefile
MY_NAME := $(lastword $(MAKEFILE_LIST))
$(MY_NAME)_PATH := $(dir $(MY_NAME))

include $($(MY_NAME)_PATH:%/=%)/$(rules_mk_path)
#### don't change before this line unless to disable standard rules generation makefile
#########################################################################################


# args to RUN_DAGON and RUN_DAGON_SPIKE: $1 = test name; $2 = ini file; $3 = timeout; $4 = wesley test command, $5 = include in CI
# NOTE: all paths must be relative to buffy directory (use buffy_path variable)

##<NAME OF TARGET>: #used as part of `make help` command ## <DESCRIPTION OF TARGET>
#$(eval $(call RUN_DAGON\
#,<NAME OF TARGET> \
#,$(buffy_path)/<PATH TO INI FILE> \
#,<TIMEOUT VALUE> \
#,<WESLEY TEST COMMAND> \
#,<INCLUDE IN CI>))

# end of prevent rules from being evaluated/included multiple times
endif
