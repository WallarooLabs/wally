rules_mk_path := ../../../../../rules.mk

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


# Set up validator specific paths. We don't know what directory make was
# run from, so we get an absolute path based on $(buffy_path). This will work
# whether make was run from the top level of Wallaroo or from within the
# validator directory.
VALIDATOR_PATH = $(buffy_path)/testing/correctness/apps/sequence-window/validator
VALIDATOR_EXAMPLES = $(VALIDATOR_PATH)/examples

# Our top level Makefile has 3 rules that would have been generated for us if
# we hadn't turned them off at the top of the Makefile. Here we recreate them
# with our own custom rules. This allows the top level commands like
# "make test" to work.
build-validator-all = validator_clean validator_build
test-validator-all = validator_clean validator_build validator_test
clean-validator-all = validator_clean

validator_clean:
	$(QUIET)rm -rf $(VALIDATOR_PATH)/validator
	$(QUIET)rm -rf $(VALIDATOR_PATH)/validator.o
	$(QUIET)rm -fr $(VALIDATOR_EXAMPLES)/*.txt

validator_build:
	stable env ponyc

validator_test:
	$(QUIET)python $(VALIDATOR_EXAMPLES)/data_gen.py
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/pass.txt
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/pass_with_atleastonce.txt -a
	$(VALIDATOR_PATH)/validator -i $(VALIDATOR_EXAMPLES)/fail_expect_max.txt -e 1002



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

