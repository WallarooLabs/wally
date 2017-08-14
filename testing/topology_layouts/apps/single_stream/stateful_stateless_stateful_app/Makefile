# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../../Makefile
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

SINGLE_STREAM_STATEFUL_STATELESS_STATEFUL_APP_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)


test-testing-topology_layouts-apps-single_stream-stateful_stateless_stateful_app: single_stream_stateful_stateless_stateful_app_test

single_stream_stateful_stateless_stateful_app_test:
	cd $(SINGLE_STREAM_STATEFUL_STATELESS_STATEFUL_APP_PATH) && \
	integration_test --framed-file-sender ../../data_gen/_test.msg \
	--validation-cmp \
	--expected-file ../../data_gen/_expected.msg \
	--log-level error \
	--command './stateful_stateless_stateful_app' \
	--sink-expect 100

# Multi-worker tests currently fail:
# Error initializing local topology
# This should never happen: failure in lib/wallaroo/initialization/local_topology.pony at line 1236
# See Issue: 947

#test-testing-topology_layouts-apps-single_stream-stateful_stateless_stateful_app: two_worker_single_stream_stateful_stateless_stateful_app_test

two_worker_single_stream_stateful_stateless_stateful_app_test:
	cd $(SINGLE_STREAM_STATEFUL_STATELESS_STATEFUL_APP_PATH) && \
	integration_test --framed-file-sender ../../data_gen/_test.msg \
	--workers 2 \
	--validation-cmp \
	--expected-file ../../data_gen/_expected.msg \
	--log-level error \
	--command './stateful_stateless_stateful_app' \
	--sink-expect 100

#test-testing-topology_layouts-apps-single_stream-stateful_stateless_stateful_app: three_worker_single_stream_stateful_stateless_stateful_app_test

three_worker_single_stream_stateful_stateless_stateful_app_test:
	cd $(SINGLE_STREAM_STATEFUL_STATELESS_STATEFUL_APP_PATH) && \
	integration_test --framed-file-sender ../../data_gen/_test.msg \
	--workers 3 \
	--validation-cmp \
	--expected-file ../../data_gen/_expected.msg \
	--log-level error \
	--command './stateful_stateless_stateful_app' \
	--sink-expect 100

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
