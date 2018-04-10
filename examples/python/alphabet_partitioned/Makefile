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


ALPHABET_PARTITIONED_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-examples-python-alphabet_partitioned: build-machida
integration-tests-examples-python-alphabet_partitioned: build-examples-python-alphabet_partitioned

integration-tests-examples-python-alphabet_partitioned: alphabet_partitioned_py_test


alphabet_partitioned_py_test:
	cd $(ALPHABET_PARTITIONED_PY_PATH) && \
	python _test/gen.py && \
	integration_test --framed-file-sender _test.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 10 \
		--output 'received.txt' \
		--command 'machida --application-module alphabet_partitioned' \
		--sink-mode newlines \
		--sink-expect 1000 \
		--workers 1
	cd $(ALPHABET_PARTITIONED_PY_PATH) && \
	python _test/gen.py && \
	integration_test --framed-file-sender _test.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 10 \
		--output 'received.txt' \
		--command 'machida --application-module alphabet_partitioned' \
		--sink-mode newlines \
		--sink-expect 1000 \
		--workers 2
	cd $(ALPHABET_PARTITIONED_PY_PATH) && \
	python _test/gen.py && \
	integration_test --framed-file-sender _test.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 10 \
		--output 'received.txt' \
		--command 'machida --application-module alphabet_partitioned' \
		--sink-mode newlines \
		--sink-expect 1000 \
		--workers 3

clean-examples-python-alphabet-partitioned: alphabet_partitioned_py_clean

alphabet_partitioned_py_clean:
	$(QUIET)rm -f $(ALPHABET_PY_PATH)/_test.txt $(ALPHABET_PY_PATH)/_expected.json

endif
