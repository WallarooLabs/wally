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

SEQUENCE_PART_PATH = $(buffy_path)/book/examples/python/sequence_partitioned

build-book-examples-python-sequence_partitioned-all += build-machida-all
build-book-examples-python-sequence_partitioned-all += build-testing-correctness-apps-sequence_window-validator-all
test-book-examples-python-sequence_partitioned-all += build-book-examples-python-sequence_partitioned-all
test-book-examples-python-sequence_partitioned-all += sequence_partitioned_py_test
clean-book-examples-python-sequence_partitioned-all += sequence_partitioned_py_clean

sequence_partitioned_py_clean:
	$(QUIET)rm -f $(SEQUENCE_PART_PATH)/received.txt

sequence_partitioned_py_test:
	cd $(SEQUENCE_PART_PATH) && \
	export PYTHONPATH="$(PYTHONPATH)" && \
	integration_test --sequence-sender '(0,1000]' \
	  --log-level error \
		--command 'machida --application-module sequence_partitioned' \
		--validation-cmd '$(VALIDATOR_PATH)/validator -e 1000 -a -i' \
		--output 'received.txt' \
		--workers 2 \
		--giles-mode \
		--sink-expect 1000


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

# end of prevent rules from being evaluated/included multiple times
endif
