# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate of PONYC command
PONYC_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false

SEQUENCE_WINDOW_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)


build-testing-correctness-apps-sequence_window: build-testing-correctness-apps-sequence_window-validator

# This will build three different binaries of sequence_window, but respect PONYCFLAGS passed
# to Make
$(subst $(abs_buffy_dir)/,,$(SEQUENCE_WINDOW_PATH:%/=%))/$(notdir $(abspath $(SEQUENCE_WINDOW_PATH:%/=%))):
	$(eval original_PONYCFLAGS := $(PONYCFLAGS))
	$(eval PONYCFLAGS := $(original_PONYCFLAGS) -D resilience -D spike -D spiketrace)
	$(call PONYC,$(abspath $(SEQUENCE_WINDOW_PATH:%/=%)))
	mv $(abspath $(SEQUENCE_WINDOW_PATH:%/=%))/sequence_window $(abspath $(SEQUENCE_WINDOW_PATH:%/=%))/sequence_window_resilience
	$(eval PONYCFLAGS := $(original_PONYCFLAGS) -D spike -D spiketrace)
	$(call PONYC,$(abspath $(SEQUENCE_WINDOW_PATH:%/=%)))
	mv $(abspath $(SEQUENCE_WINDOW_PATH:%/=%))/sequence_window $(abspath $(SEQUENCE_WINDOW_PATH:%/=%))/sequence_window_spike
	$(eval PONYCFLAGS := $(original_PONYCFLAGS))
	$(call PONYC,$(abspath $(SEQUENCE_WINDOW_PATH:%/=%)))

test-testing-correctness-apps-sequence_window: build-testing-correctness-apps-sequence_window

test-testing-correctness-apps-sequence_window: sequence_window_test

sequence_window_test:
	cd $(SEQUENCE_WINDOW_PATH) && \
	integration_test --sequence-sender '(0,1000]' \
	  --log-level error \
		--command './sequence_window' \
		--validation-cmd './validator/validator -e 1000 -a -i' \
		--output 'received.txt' \
		--giles-mode \
		--workers 2 \
		--batch-size 10 \
		--sink-expect 1000

clean-testing-correctness-apps-sequence_window: sequence_window_clean

sequence_window_clean:
	$(QUIET)rm -fr $(SEQUENCE_WINDOW_PATH)/sequence_window*

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
