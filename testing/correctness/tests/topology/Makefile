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
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := true

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := true

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := true

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := true

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := true

TOPOLOGY_TESTS_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)


build-testing-correctness-tests-topology: build-machida
#!@
# build-testing-correctness-tests-topology: build-machida3
unit-tests-testing-correctness-tests-topology: topology_python_unit_tests
integration-tests-testing-correctness-tests-topology: build-testing-correctness-tests-topology
integration-tests-testing-correctness-tests-topology: topology_tests

topology_python_unit_tests:
	cd $(TOPOLOGY_TESTS_PATH) && \
		python2 -m pytest -c $(integration_path)/pytest.ini components.py && \
		python3 -m pytest -c $(integration_path)/pytest.ini components.py

topology_tests:
	cd $(TOPOLOGY_TESTS_PATH) && \
		python3 -m pytest -c $(integration_path)/pytest.ini topology_tests.py $(pytest_exp)

# end of prevent rules from being evaluated/included multiple times
endif
