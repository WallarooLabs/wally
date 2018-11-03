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


TESTING_ALPHABET_PYTHON27_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-testing-correctness-apps-alphabet_python27: build-machida
build-testing-correctness-apps-alphabet_python27: build-machida3
integration-tests-testing-correctness-apps-alphabet_python27: build-testing-correctness-apps-alphabet_python27
integration-tests-testing-correctness-apps-alphabet_python27: testing_alphabet_python27_test
integration-tests-testing-correctness-apps-alphabet_python27: testing_alphabet_python27_python3_test

testing_alphabet_python27_test:
	cd $(TESTING_ALPHABET_PYTHON27_PATH) && \
	integration_test \
		--framed-file-sender input.msg \
		--framed-file-sender input.msg \
		--framed-file-sender input.msg \
		--framed-file-sender input.msg \
		--validation-cmd 'python validate.py --expected output.json --repetitions 4 --output' \
		--log-level error \
		--batch-size 10 \
		--output 'received.txt' \
		--command 'machida --application-module alphabet27' \
		--workers 1 \
		--sink-expect 4000

testing_alphabet_python27_python3_test:
	cd $(TESTING_ALPHABET_PYTHON27_PATH) && \
	integration_test \
		--framed-file-sender input.msg \
		--framed-file-sender input.msg \
		--framed-file-sender input.msg \
		--framed-file-sender input.msg \
		--validation-cmd 'python validate.py --expected output.json --repetitions 4 --output' \
		--log-level error \
		--batch-size 10 \
		--output 'received.txt' \
		--command 'machida3 --application-module alphabet27' \
		--workers 1 \
		--sink-expect 4000

endif
