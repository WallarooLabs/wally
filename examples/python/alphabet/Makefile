# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
RECURSE_SUBMAKEFILES := false

ALPHABET_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-examples-python-alphabet: build-machida
test-examples-python-alphabet: build-examples-python-alphabet

test-examples-python-alphabet: alphabet_py_test

alphabet_py_test:
	cd $(ALPHABET_PY_PATH) && \
	python _test/gen.py && \
	integration_test --framed-file-sender _test.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 10 \
		--output 'received.txt' \
		--command 'machida --application-module alphabet' \
		--sink-expect 1000

clean-examples-python-alphabet: alphabet_py_clean

alphabet_py_clean:
	$(QUIET)rm -f $(ALPHABET_PY_PATH)/_test.txt $(ALPHABET_PY_PATH)/_expected.json

endif
