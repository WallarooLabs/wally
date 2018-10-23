# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../Makefile
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


MARKET_SPREAD_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-examples-python-market_spread: build-machida
# build-examples-python-market_spread: build-machida3
integration-tests-examples-python-market_spread: build-examples-python-market_spread
integration-tests-examples-python-market_spread: market_spread_py_test
# integration-tests-examples-python-market_spread: market_spread_py3_test

market_spread_py_test:
	cd $(MARKET_SPREAD_PY_PATH) && \
	python _test/gen.py && \
	integration_test \
		--framed-file-sender _market.txt 1 \
		--framed-file-sender _orders.txt 0 \
		--log-level error \
		--command 'machida --application-module market_spread' \
		--validation-cmd 'python _test/validate.py --expected $(MARKET_SPREAD_PY_PATH)/_expected.txt --output' \
		--output 'received.txt' \
		--workers 5 \
		--sources 2 \
		--sink-mode framed \
		--sink-expect 1000

market_spread_py3_test:
	cd $(MARKET_SPREAD_PY_PATH) && \
	python _test/gen.py && \
	integration_test \
		--framed-file-sender _market.txt 1 \
		--framed-file-sender _orders.txt 0 \
		--log-level error \
		--command 'machida3 --application-module market_spread' \
		--validation-cmd 'python _test/validate.py --expected $(MARKET_SPREAD_PY_PATH)/_expected.txt --output' \
		--output 'received.txt' \
		--workers 5 \
		--sources 2 \
		--sink-mode framed \
		--sink-expect 1000

clean-examples-python-market_spread: market_spread_py_clean

market_spread_py_clean:
	$(QUIET)rm -f $(MARKET_SPREAD_PY_PATH)/received.txt $(MARKET_SPREAD_PY_PATH)/_expected.txt $(MARKET_SPREAD_PY_PATH)/_orders.txt $(MARKET_SPREAD_PY_PATH)/_market.txt

endif
