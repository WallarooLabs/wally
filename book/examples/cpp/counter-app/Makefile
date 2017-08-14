# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../Makefile
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

COUNTER_PATH = $(buffy_path)/book/examples/cpp/counter-app
COUNTER_BUILD = $(COUNTER_PATH)/build
COUNTER_CPP = $(COUNTER_PATH)/cpp
COUNTER_HPP = $(COUNTER_PATH)/hpp
COUNTER_PONY_SOURCE = $(COUNTER_PATH)/counter-app
WALLAROO_LIB =  $(buffy_path)/lib
CPP_PONY_LIB = $(buffy_path)/cpp_api/
WALLAROO_CPP_INSTALL = /tmp/cpp_api
WALLAROO_CPP_LIB = $(WALLAROO_CPP_INSTALL)/lib/WallarooCppApi
WALLAROO_CPP_INCLUDE = $(WALLAROO_CPP_INSTALL)/include/

build-book-examples-cpp-counter-app-all = build-cpp_api-all counter_app_clean counter_app_build
test-book-examples-cpp-counter-app-all = build-book-examples-cpp-counter-app-all counter_app_test
clean-book-examples-cpp-counter-app-all = clean-cpp_api-all counter_app_clean

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
