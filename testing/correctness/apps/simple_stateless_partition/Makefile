# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

rules_mk_path := ../../../../rules.mk

# uncomment to disable generate test related targets in this directory
#TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false


build-testing-correctness-apps-sequence_window-all = sequence_window_clean sequence_window_build
test-testing-correctness-apps-sequence_window-all = build-testing-correctness-apps-sequence_window-all build-testing-correctness-apps-sequence_window-validator-all sequence_window_test
clean-testing-correctness-apps-sequence_window-all = sequence_window_clean
build-testing-correctness-apps-sequence_window-recovery-spike = sequence_window_build_recovery_spike

SEQUENCE_WINDOW_PATH = $(buffy_path)/testing/correctness/apps/sequence_window
VALIDATOR_PATH = $(buffy_path)/testing/correctness/apps/sequence_window/validator
INTEGRATION_PATH = $(buffy_path)/testing/tools
INTEGRATION_BIN_PATH = $(INTEGRATION_PATH)/integration
WALLAROO_LIB =  $(buffy_path)/lib


sequence_window_clean:
	$(QUIET)rm -f $(SEQUENCE_WINDOW_PATH)/sequence_window
	$(QUIET)rm -f $(SEQUENCE_WINDOW_PATH)/sequence_window.o

sequence_window_build:
	cd $(SEQUENCE_WINDOW_PATH) && \
	stable env ponyc --path=$(WALLAROO_LIB) --path=$(SEQUENCE_WINDOW_PATH) $(SEQUENCE_WINDOW_PATH) -D resilience -D spike -D spiketrace

sequence_window_build_recovery_spike:
	cd $(SEQUENCE_WINDOW_PATH) && \
	stable env ponyc -D resilience -D spike -D spiketrace

sequence_window_test:
	export PATH="$(PATH):$(INTEGRATION_BIN_PATH)" && \
	rm -f /tmp/sequence* && \
	cd $(SEQUENCE_WINDOW_PATH) && \
	integration_test --sequence-sender '(0,1000]' \
	  --log-level error \
		--command '$(SEQUENCE_WINDOW_PATH)/sequence_window' \
		--validation-cmd '$(SEQUENCE_WINDOW_PATH)/validator/validator -e 1000 -a -i' \
		--output 'received.txt' \
		--giles-mode \
		--workers 2 \
		--batch-size 10 \
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
