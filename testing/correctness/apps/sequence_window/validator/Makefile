# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1


# The following are control variables that determine what logic from `rules.mk` is enabled

# `true`/`false` to enable/disable the actual test command so it can be overridden (the targets are still created)
# applies to both the pony and elixir test targets
$(abspath $(lastword $(MAKEFILE_LIST)))_TEST_COMMAND := false

# `true`/`false` to enable/disable generate pony related targets (build/test/clean) for pony sources in this directory
# otherwise targets only get created if there are pony sources (*.pony) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := true

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := true

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := true

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := true

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := true


VALIDATOR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
VALIDATOR_EXAMPLES := $(VALIDATOR_PATH)/examples

# standard rules generation makefile
include $(rules_mk_path)


test-testing-correctness-apps-sequence_window-validator: validator_test
clean-testing-correctness-apps-sequence_window-validator: validator_clean

validator_clean:
	$(QUIET)rm -f $(VALIDATOR_PATH)/validator
	$(QUIET)rm -f $(VALIDATOR_PATH)/validator.o
	$(QUIET)rm -fr $(VALIDATOR_EXAMPLES)/*.txt

validator_test:
	$(QUIET)python $(VALIDATOR_EXAMPLES)/data_gen.py
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/pass.txt
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/pass_with_atleastonce.txt -a
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/fail_expect_max.txt -e 1002

# end of prevent rules from being evaluated/included multiple times
endif

