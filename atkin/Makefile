# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

rules_mk_path := ../rules.mk

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
RECURSE_SUBMAKEFILES := false

# Set up our atkin specific paths. We don't know what directory make was
# run from, so we get an absolute path based on $(buffy_path). This will work
# whether make was run from the top level of Wallaroo or from within the
# atkin directory.
ATKIN_PATH = $(buffy_path)/atkin
ATKIN_BUILD = $(ATKIN_PATH)/build
ATKIN_CPP = $(ATKIN_PATH)/cpp
WALLAROO_LIB =  $(buffy_path)/lib

# Our top level Makefile has 3 rules that would have been generated for us if
# we hadn't turned them off at the top of the Makefile. Here we recreate them
# with our own custom rules. This allows the top level commands like
# "make test" to work.
build-atkin-all = atkin_clean atkin_build
test-atkin-all = atkin_clean atkin_build atkin_test
clean-atkin-all = atkin_clean

atkin_clean:
	rm -rf $(ATKIN_BUILD)

atkin_build:
	mkdir -p $(ATKIN_BUILD)
	cc -g -o $(ATKIN_BUILD)/python-wactor.o -c $(ATKIN_CPP)/python-wactor.c
	ar rvs $(ATKIN_BUILD)/libpython-wactor.a $(ATKIN_BUILD)/python-wactor.o
	ponyc --debug --output=$(ATKIN_BUILD) --path=$(ATKIN_BUILD) --path=$(WALLAROO_LIB) $(ATKIN_PATH)

atkin_test:
	$(QUIET)echo "atkin tests"

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
