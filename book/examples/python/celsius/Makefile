# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

rules_mk_path := ../../../../rules.mk

# uncomment to disable generate test related targets in this directory
#TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
RECURSE_SUBMAKEFILES := false

PYTHON_PATH = $(buffy_path)/machida
MACHIDA_BIN_PATH = $(buffy_path)/machida/build
INTEGRATION_PATH = $(buffy_path)/testing/tools
INTEGRATION_BIN_PATH = $(INTEGRATION_PATH)/integration
CELSIUS_PY_PATH = $(buffy_path)/book/examples/python/celsius

build-book-examples-python-celsius-all = build-machida-all
test-book-examples-python-celsius-all = build-book-examples-python-celsius-all celsius_py_test

celsius_py_test:
	export PYTHONPATH=".:$(PYTHON_PATH):$(INTEGRATION_PATH)" && \
	export PATH="$(PATH):$(MACHIDA_BIN_PATH):$(INTEGRATION_BIN_PATH)" && \
	cd $(CELSIUS_PY_PATH) && \
	integration_test --framed-file-sender \
	  _test.txt --validation-cmp \
	  --expected-file _expected.txt \
		--log-level error \
		--command 'machida --application-module celsius' \
		--sink-expect 100



#########################################################################################
#### don't change after this line unless to disable standard rules generation makefile
MY_NAME := $(lastword $(MAKEFILE_LIST))
$(MY_NAME)_PATH := $(dir $(MY_NAME))

include $($(MY_NAME)_PATH:%/=%)/$(rules_mk_path)
#### don't change before this line unless to disable standard rules generation makefile
#########################################################################################


# args to RUN_DAGON and RUN_DAGON_SPIKE: $1 = test name; $2 = ini file; $3 = timeout; $4 = wesley test command, $5 = include in CI
# NOTE: all paths must be relative to buffy directory (use buffy_path variable)

##<NAME OF TARGET>: #used as part of `make help` command ## <DESCRIPTION OF TARGET>
#$(eval $(call RUN_DAGON\
#,<NAME OF TARGET> \
#,$(buffy_path)/<PATH TO INI FILE> \
#,<TIMEOUT VALUE> \
#,<WESLEY TEST COMMAND> \
#,<INCLUDE IN CI>))
endif
