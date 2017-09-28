# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

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
