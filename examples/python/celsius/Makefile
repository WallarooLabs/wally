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

CELSIUS_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)


build-examples-python-celsius: build-machida
test-examples-python-celsius: build-examples-python-celsius

test-examples-python-celsius: celsius_py_test

celsius_py_test:
	cd $(CELSIUS_PY_PATH) && \
	integration_test --framed-file-sender \
	  _test.txt --validation-cmp \
	  --expected-file _expected.txt \
		--log-level error \
		--command 'machida --application-module celsius' \
		--sink-expect 100

endif
