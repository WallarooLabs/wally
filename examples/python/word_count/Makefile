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


WORD_COUNT_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-examples-python-word_count: build-machida
build-examples-python-word_count: build-machida3
integration-tests-examples-python-word_count: build-examples-python-word_count
integration-tests-examples-python-word_count: word_count_py_test
integration-tests-examples-python-word_count: word_count_py3_test
clean-examples-python-alphabet: word_count_py_clean

word_count_py_test:
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test \
		--newline-file-sender count_this.txt "'Split and Count'" \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida --application-module word_count $(RUN_WITH_RESILIENCE)' \
		--sink-mode newlines \
		--sink-expect 482
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test \
	  --newline-file-sender count_this.txt "'Split and Count'" \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida --application-module word_count $(RUN_WITH_RESILIENCE)' \
		--sink-mode newlines \
		--sink-expect 482 \
		--workers 2
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test \
		--newline-file-sender count_this.txt "'Split and Count'" \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida --application-module word_count $(RUN_WITH_RESILIENCE)' \
		--sink-mode newlines \
		--sink-expect 482 \
		--workers 3

word_count_py3_test:
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test \
		--newline-file-sender count_this.txt "'Split and Count'" \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida3 --application-module word_count $(RUN_WITH_RESILIENCE)' \
		--sink-mode newlines \
		--sink-expect 482
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test \
		--newline-file-sender count_this.txt "'Split and Count'" \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida3 --application-module word_count $(RUN_WITH_RESILIENCE)' \
		--sink-mode newlines \
		--sink-expect 482 \
		--workers 2
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test \
		--newline-file-sender count_this.txt "'Split and Count'" \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida3 --application-module word_count $(RUN_WITH_RESILIENCE)' \
		--sink-mode newlines \
		--sink-expect 482 \
		--workers 3

word_count_py_clean:
	$(QUIET)rm -f $(WORD_COUNT_PY_PATH)/received.txt

endif
