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
MACHIDA_PATH = $(wallaroo_path)/machida
MACHIDA_BUILD = $(MACHIDA_PATH)/build
MACHIDA_CPP = $(MACHIDA_PATH)/cpp
WALLAROO_LIB =  $(wallaroo_path)/lib

# Our top level Makefile has 3 rules that would have been generated for us if
# we hadn't turned them off at the top of the Makefile. Here we recreate them
# with our own custom rules. This allows the top level commands like
# "make test" to work.
build-machida: machida_build
unit-tests-machida: build-machida
unit-tests-machida: wallaroo_unit_tests
clean-machida: machida_clean

machida_clean:
	$(QUIET)rm -rf $(MACHIDA_BUILD)
	$(QUIET)rm -f $(MACHIDA_PATH)/machida.d
	$(QUIET)rm -rf $(MACHIDA_PATH)/.deps


wallaroo_unit_tests:
	cd $(MACHIDA_PATH) && \
		python2 -m pytest --color=yes --tb=native --verbose --exitfirst wallaroo_test.py && \
		python3 -m pytest --color=yes --tb=native --verbose --exitfirst wallaroo_test.py

machida_build: $(MACHIDA_BUILD)/machida

-include $(MACHIDA_PATH)/machida.d
$(MACHIDA_BUILD)/machida: EXTRA_PONYCFLAGS= --output=$(MACHIDA_BUILD) --path=$(MACHIDA_BUILD)
$(MACHIDA_BUILD)/machida: $(MACHIDA_BUILD)/libpython-wallaroo.a
	$(call PONYC,$(abspath $(MACHIDA_PATH:%/=%)))

$(MACHIDA_BUILD)/libpython-wallaroo.a: $(MACHIDA_BUILD)/python-wallaroo.o
	$(QUIET)ar rvs $(MACHIDA_BUILD)/libpython-wallaroo.a $(MACHIDA_BUILD)/python-wallaroo.o

$(MACHIDA_BUILD)/python-wallaroo.o: $(MACHIDA_CPP)/python-wallaroo.c
	$(QUIET)mkdir -p $(MACHIDA_BUILD)
	$(QUIET)cc -g -o $(MACHIDA_BUILD)/python-wallaroo.o -c $(MACHIDA_CPP)/python-wallaroo.c

# end of prevent rules from being evaluated/included multiple times
endif
