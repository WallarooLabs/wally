# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../Makefile
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


ifeq ($(shell uname -s),Linux)
	PONY_LINKER = --linker g++
endif

MSCPP_PATH = $(wallaroo_path)/testing/performance/apps/market-spread-cpp
MSCPP_BUILD = $(MSCPP_PATH)/build
MSCPP_CPP = $(MSCPP_PATH)/cpp
MSCPP_HPP = $(MSCPP_PATH)/hpp
MSCPP_PONY_SOURCE = $(MSCPP_PATH)/market-spread-cpp
WALLAROO_LIB =  $(wallaroo_path)/lib
CPP_PONY_LIB = $(wallaroo_path)/cpp_api/
WALLAROO_CPP_INSTALL = /tmp/cpp_api
WALLAROO_CPP_LIB = $(WALLAROO_CPP_INSTALL)/lib/WallarooCppApi
WALLAROO_CPP_INCLUDE = $(WALLAROO_CPP_INSTALL)/include/


# build-testing-performance-apps-market-spread-cpp-all = build-cpp_api-all marketspread_cpp_clean marketspread_cpp_build
# unit-tests-testing-performance-apps-market-spread-cpp-all = build-testing-performance-apps-market-spread-cpp-all marketspread_cpp_test
# clean-testing-performance-apps-market-spread-cpp-all = clean-cpp_api-all marketspread_cpp_clean

# marketspread_cpp_build:
# 	$(QUIET)mkdir -p $(MSCPP_BUILD)
# 	$(QUIET)c++ $(debug_arg) -c -o $(MSCPP_BUILD)/market-spread-cpp.o $(MSCPP_CPP)/market-spread-cpp.cpp -Wall -std=c++11 -I$(MSCPP_HPP) -I$(WALLAROO_CPP_INCLUDE)
# 	$(QUIET)ar rs $(MSCPP_BUILD)/libmarket-spread-cpp.a $(MSCPP_BUILD)/market-spread-cpp.o
# 	$(QUIET)ponyc $(PONY_LINKER) $(debug_arg) --export --output=$(MSCPP_BUILD) --path $(WALLAROO_LIB):$(CPP_PONY_LIB):$(WALLAROO_CPP_LIB):$(MSCPP_BUILD) $(MSCPP_PONY_SOURCE)

# marketspread_cpp_clean:
# 	$(QUIET)rm -rf $(MSCPP_BUILD)

# marketspread_cpp_test:
# 	$(QUIET)echo "market-spread-cpp tests"

# standard rules generation makefile
include $(rules_mk_path)

# end of prevent rules from being evaluated/included multiple times
endif

