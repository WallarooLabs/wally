# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# The following are control variables that determine what logic from `rules.mk` is enabled

# `true`/`false` to enable/disable the actual unit test command so it can be overridden (the targets are still created)
# applies to both the pony and elixir test targets
$(abspath $(lastword $(MAKEFILE_LIST)))_UNIT_TEST_COMMAND := false

# `true`/`false` to enable/disable generate pony related targets (build/test/clean) for pony sources in this directory
# otherwise targets only get created if there are pony sources (*.pony) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := false

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := false

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := false

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := false

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := false

ALOC_SINK_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
aloc_sink_tests : CUSTOM_PATH = $(MULTI_PARTITION_DETECTOR_PATH):$(MULTI_PART_VALIDATOR_PATH):$(CLUSTER_SHRINKER_PATH)
aloc_sink_tests : CUSTOM_PYTHONPATH = $(MULTI_PARTITION_DETECTOR_PATH):$(WINDOW_DETECTOR_PATH)

# standard rules generation makefile
include $(rules_mk_path)

build-testing-correctness-tests-aloc_sink: build-machida
integration-tests-testing-correctness-tests-aloc_sink: build-testing-correctness-tests-aloc_sink
integration-tests-testing-correctness-tests-aloc_sink: aloc_sink_tests

ifeq ($(resilience),on)
aloc_sink_tests:
	-rm -fv /tmp/Celsius* /tmp/aloc*
	#### -cd $(HOME)/s/src/other-repo && make start-s3-container
	-cd $(ALOC_SINK_PATH) && ./run_aloc_sink_test > /tmp/run_aloc_sink_test.out 2>&1
	cd $(ALOC_SINK_PATH) && ./run_aloc_sink_test.validate.sh
else
aloc_sink_tests:
	$(QUIET)printf "aloc_sink tests not run.\nRun make with 'resilience=on' to run this test.\n"
endif

endif
