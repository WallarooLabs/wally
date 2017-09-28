# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1


# The following are control variables that determine what logic from `rules.mk` is enabled

# `true`/`false` to enable/disable the actual test command so it can be overridden (the targets are still created)
# applies to both the pony and elixir test targets
$(abspath $(lastword $(MAKEFILE_LIST)))_TEST_COMMAND := true

# `true`/`false` to enable/disable generate pony related targets (build/test/clean) for pony sources in this directory
# otherwise targets only get created if there are pony sources (*.pony) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := false

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := true

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := false

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := false

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := false


ifeq ($(shell uname -s),Linux)
	PONY_LINKER = --linker g++
endif

COUNTER_PATH = $(wallaroo_path)/examples/cpp/counter-app
COUNTER_BUILD = $(COUNTER_PATH)/build
COUNTER_CPP = $(COUNTER_PATH)/cpp
COUNTER_HPP = $(COUNTER_PATH)/hpp
COUNTER_PONY_SOURCE = $(COUNTER_PATH)/counter-app
WALLAROO_LIB =  $(wallaroo_path)/lib
CPP_PONY_LIB = $(wallaroo_path)/cpp_api/
WALLAROO_CPP_INSTALL = /tmp/cpp_api
WALLAROO_CPP_LIB = $(WALLAROO_CPP_INSTALL)/lib/WallarooCppApi
WALLAROO_CPP_INCLUDE = $(WALLAROO_CPP_INSTALL)/include/

build-examples-cpp-counter-app-all = build-cpp_api-all counter_app_clean counter_app_build
test-examples-cpp-counter-app-all = build-examples-cpp-counter-app-all counter_app_test
clean-examples-cpp-counter-app-all = clean-cpp_api-all counter_app_clean

counter_app_build:
	mkdir -p $(COUNTER_BUILD)
	c++ --debug -c -o $(COUNTER_BUILD)/Counter.o $(COUNTER_CPP)/Counter.cpp -Wall -std=c++11 -I$(COUNTER_HPP) -I$(WALLAROO_CPP_INCLUDE)
	ar rs $(COUNTER_BUILD)/libcounter.a $(COUNTER_BUILD)/Counter.o
	ponyc $(PONY_LINKER) --debug --export --output=$(COUNTER_BUILD) --path $(WALLAROO_LIB):$(CPP_PONY_LIB):$(WALLAROO_CPP_LIB):$(COUNTER_BUILD) $(COUNTER_PONY_SOURCE)

counter_app_clean:
	rm -rf $(COUNTER_BUILD)

counter_app_test:
	$(QUIET)echo "counter-app tests"

# standard rules generation makefile
include $(rules_mk_path)

# end of prevent rules from being evaluated/included multiple times
endif
