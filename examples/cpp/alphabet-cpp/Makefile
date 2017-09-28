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

WALLAROO_LIB =  $(wallaroo_path)/lib
CPP_PONY_LIB = $(wallaroo_path)/cpp_api/
WALLAROO_CPP_INSTALL = /tmp/cpp_api
WALLAROO_CPP_LIB = $(WALLAROO_CPP_INSTALL)/lib/WallarooCppApi
WALLAROO_CPP_INCLUDE = $(WALLAROO_CPP_INSTALL)/include/
ALPHABET_PATH = $(wallaroo_path)/examples/cpp/alphabet-cpp
ALPHABET_BUILD = $(ALPHABET_PATH)/build
ALPHABET_CPP = $(ALPHABET_PATH)/cpp
ALPHABET_HPP = $(ALPHABET_PATH)/include
ALPHABET_PONY_SOURCE = $(ALPHABET_PATH)/alphabet-app

build-examples-cpp-alphabet-cpp-all = build-cpp_api-all alphabet_cpp_clean alphabet_cpp_build
test-examples-cpp-alphabet-cpp-all = build-examples-cpp-alphabet-cpp-all alphabet_cpp_test
clean-examples-cpp-alphabet-cpp-all = clean-cpp_api-all alphabet_cpp_clean

alphabet_cpp_build:
	mkdir -p $(ALPHABET_BUILD)
	c++ --debug -c -o $(ALPHABET_BUILD)/alphabet.o $(ALPHABET_CPP)/alphabet.cpp -Wall -std=c++11 -I$(ALPHABET_HPP) -I$(WALLAROO_CPP_INCLUDE)
	ar rs $(ALPHABET_BUILD)/libalphabet.a $(ALPHABET_BUILD)/alphabet.o
	ponyc $(PONY_LINKER) --debug --export --output=$(ALPHABET_BUILD) --path $(WALLAROO_LIB):$(CPP_PONY_LIB):$(WALLAROO_CPP_LIB):$(ALPHABET_BUILD) $(ALPHABET_PONY_SOURCE)

alphabet_cpp_clean:
	rm -rf $(ALPHABET_BUILD)

alphabet_cpp_test:
	$(QUIET)echo "alphabet-cpp tests"

# standard rules generation makefile
include $(rules_mk_path)

# end of prevent rules from being evaluated/included multiple times
endif
