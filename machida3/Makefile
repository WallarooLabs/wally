# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1


# The following are control variables that determine what logic from `rules.mk` is enabled

# `true`/`false` to enable/disable the actual unit test command so it can be overridden (the targets are still created)
# applies to both the pony and elixir test targets
$(abspath $(lastword $(MAKEFILE_LIST)))_UNIT_TEST_COMMAND := false

# `true`/`false` to enable/disable generate pony related targets (build/test/clean) for pony sources in this directory
# otherwise targets only get created if there are pony sources (*.pony) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := false

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := false

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := false

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := false

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := false


# standard rules generation makefile
include $(rules_mk_path)


# Set up our machida specific paths. We don't know what directory make was
# run from, so we get an absolute path based on $(wallaroo_path). This will work
# whether make was run from the top level of Wallaroo or from within the
# machida directory.
MACHIDA3_PATH = $(wallaroo_path)/machida3
MACHIDA3_BUILD = $(MACHIDA3_PATH)/build
MACHIDA3_CPP = $(MACHIDA3_PATH)/cpp
WALLAROO_LIB =  $(wallaroo_path)/lib

#PYTHON3 = python3
PYTHON3 = python3-dbg
PYTHON3_INCLUDES = $(shell $(PYTHON3)-config --includes)
PYTHON3_LIBS = $(shell $(PYTHON3)-config --libs)

# Our top level Makefile has 3 rules that would have been generated for us if
# we hadn't turned them off at the top of the Makefile. Here we recreate them
# with our own custom rules. This allows the top level commands like
# "make test" to work.
build-machida3: machida3_build
clean-machida3: machida3_clean

machida3_clean:
	$(QUIET)rm -rf $(MACHIDA3_BUILD)
	$(QUIET)rm -f $(MACHIDA3_PATH)/machida.d
	$(QUIET)rm -rf $(MACHIDA3_PATH)/.deps


machida3_build: $(MACHIDA3_BUILD)/machida3

-include $(MACHIDA3_PATH)/machida.d
$(MACHIDA3_BUILD)/machida3: EXTRA_PONYCFLAGS= --output=$(MACHIDA3_BUILD) --path=$(MACHIDA3_BUILD) --linker '$(CC) $(PYTHON3_LIBS)'
$(MACHIDA3_BUILD)/machida3: $(MACHIDA3_BUILD)/libpython-wallaroo.a
	$(call PONYC,$(abspath $(MACHIDA3_PATH:%/=%)))

$(MACHIDA3_BUILD)/libpython-wallaroo.a: $(MACHIDA3_BUILD)/python-wallaroo.o
	$(QUIET)ar rvs $(MACHIDA3_BUILD)/libpython-wallaroo.a $(MACHIDA3_BUILD)/python-wallaroo.o

$(MACHIDA3_BUILD)/python-wallaroo.o: $(MACHIDA3_CPP)/python-wallaroo.c
	$(QUIET)mkdir -p $(MACHIDA3_BUILD)
	$(QUIET)cc -g -o $(MACHIDA3_BUILD)/python-wallaroo.o $(PYTHON3_INCLUDES) -c $(MACHIDA3_CPP)/python-wallaroo.c

# end of prevent rules from being evaluated/included multiple times
endif
