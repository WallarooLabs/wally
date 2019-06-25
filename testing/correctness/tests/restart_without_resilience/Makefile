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

RESTART_WITHOUT_RESILIENCE_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
restart_without_resilience_tests : CUSTOM_PATH = $(SEQUENCE_WINDOW_PATH):$(VALIDATOR_PATH)
restart_without_resilience_tests : CUSTOM_PYTHONPATH = $(SEQUENCE_WINDOW_PYTHON_PATH)

# standard rules generation makefile
include $(rules_mk_path)


build-testing-correctness-tests-restart_without_resilience: build-machida
build-testing-correctness-tests-restart_without_resilience: build-machida3
integration-tests-testing-correctness-tests-restart_without_resilience: build-testing-correctness-tests-restart_without_resilience
integration-tests-testing-correctness-tests-restart_without_resilience: restart_without_resilience_tests

ifeq ($(resilience),on)
restart_without_resilience_tests:
	$(QUIET)printf "restart_without_resilience_tests not run.\nRun make with 'resilience=off' to run this test.\n"
else
restart_without_resilience_tests:
	cd $(RESTART_WITHOUT_RESILIENCE_PATH) && \
	python3 -m pytest -c $(integration_path)/pytest.ini restart_without_resilience.py $(pytest_exp)
endif

endif
