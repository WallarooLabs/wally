# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

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
# test-testing-performance-apps-market-spread-cpp-all = build-testing-performance-apps-market-spread-cpp-all marketspread_cpp_test
# clean-testing-performance-apps-market-spread-cpp-all = clean-cpp_api-all marketspread_cpp_clean

# marketspread_cpp_build:
# 	mkdir -p $(MSCPP_BUILD)
# 	c++ --debug -c -o $(MSCPP_BUILD)/market-spread-cpp.o $(MSCPP_CPP)/market-spread-cpp.cpp -Wall -std=c++11 -I$(MSCPP_HPP) -I$(WALLAROO_CPP_INCLUDE)
# 	ar rs $(MSCPP_BUILD)/libmarket-spread-cpp.a $(MSCPP_BUILD)/market-spread-cpp.o
# 	ponyc $(PONY_LINKER) --debug --export --output=$(MSCPP_BUILD) --path $(WALLAROO_LIB):$(CPP_PONY_LIB):$(WALLAROO_CPP_LIB):$(MSCPP_BUILD) $(MSCPP_PONY_SOURCE)

# marketspread_cpp_clean:
# 	rm -rf $(MSCPP_BUILD)

# marketspread_cpp_test:
# 	$(QUIET)echo "market-spread-cpp tests"

# standard rules generation makefile
include $(rules_mk_path)

# end of prevent rules from being evaluated/included multiple times
endif

