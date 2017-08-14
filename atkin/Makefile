# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
RECURSE_SUBMAKEFILES := false

# standard rules generation makefile
include $(rules_mk_path)


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
build-atkin: atkin_build
test-atkin: build-atkin
clean-atkin: atkin_clean

atkin_clean:
	rm -rf $(ATKIN_BUILD)

atkin_build: $(ATKIN_BUILD)/atkin

$(ATKIN_BUILD)/atkin: $(ATKIN_BUILD)/libpython-wactor.a
	$(eval original_PONYCFLAGS := $(PONYCFLAGS))
	$(eval PONYCFLAGS := $(original_PONYCFLAGS) --output=$(ATKIN_BUILD) --path=$(ATKIN_BUILD))
	$(call PONYC,$(abspath $(ATKIN_PATH:%/=%)))
	$(eval PONYCFLAGS := $(original_PONYCFLAGS))

$(ATKIN_BUILD)/libpython-wactor.a: $(ATKIN_BUILD)/python-wactor.o
	ar rvs $(ATKIN_BUILD)/libpython-wactor.a $(ATKIN_BUILD)/python-wactor.o

$(ATKIN_BUILD)/python-wactor.o: $(ATKIN_CPP)/python-wactor.c
	mkdir -p $(ATKIN_BUILD)
	cc -g -o $(ATKIN_BUILD)/python-wactor.o -c $(ATKIN_CPP)/python-wactor.c

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
