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


PARALLEL_CLASSIFIER_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-examples-python-parallel_classifier: build-machida
integration-tests-examples-python-parallel_classifier: build-examples-python-parallel_classifier
integration-tests-examples-python-parallel_classifier: parallel_classifier_py_test
clean-examples-python-alphabet: parallel_classifier_py_clean

INPUT_ITEMS:=15
.PHONY: generate_inputs
generate_inputs:
	seq 1 $(INPUT_ITEMS) > inputs.txt

parallel_classifier_py_test: generate_inputs
	cd $(PARALLEL_CLASSIFIER_PY_PATH) && \
	 integration_test --newline-file-sender inputs.txt \
	 	--validation-cmd 'validate.py 1 $(INPUT_ITEMS)' \
	 	--output 'received.txt' \
	 	--batch-size 100 \
	 	--log-level debug \
	 	--command 'machida --application-module parallel_classifier' \
	 	--sink-mode framed \
	 	--sink-stop-timeout 10 \
	 	--sink-expect $(INPUT_ITEMS)
	cd $(PARALLEL_CLASSIFIER_PY_PATH) && \
	integration_test --newline-file-sender inputs.txt \
		--validation-cmd './validate.py 2 $(INPUT_ITEMS)' \
		--output 'received.txt' \
		--log-level debug \
		--batch-size 100 \
		--command 'machida --application-module parallel_classifier' \
		--sink-mode framed \
		--sink-expect $(INPUT_ITEMS) \
		--sink-stop-timeout 20 \
		--workers 2
	cd $(PARALLEL_CLASSIFIER_PY_PATH) && \
	integration_test --newline-file-sender inputs.txt \
		--validation-cmd './validate.py 5 $(INPUT_ITEMS)' \
		--output 'received.txt' \
		--log-level debug \
		--batch-size 100 \
		--command 'machida --application-module parallel_classifier' \
		--sink-mode framed \
		--sink-expect $(INPUT_ITEMS) \
		--sink-stop-timeout 20 \
		--workers 5

parallel_classifier_py_clean:
	$(QUIET)rm -f $(PARALLEL_CLASSIFIER_PY_PATH)/received.txt
	$(QUIET)rm -f $(PARALLEL_CLASSIFIER_PY_PATH)/inputs.txt

endif
