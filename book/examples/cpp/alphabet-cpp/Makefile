rules_mk_path := ../../../../rules.mk

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

WALLAROO_LIB =  $(buffy_path)/lib
CPP_PONY_LIB = $(buffy_path)/cpp_api/
WALLAROO_CPP_INSTALL = /tmp/cpp_api
WALLAROO_CPP_LIB = $(WALLAROO_CPP_INSTALL)/lib/WallarooCppApi
WALLAROO_CPP_INCLUDE = $(WALLAROO_CPP_INSTALL)/include/
ALPHABET_PATH = $(buffy_path)/book/examples/cpp/alphabet-cpp
ALPHABET_BUILD = $(ALPHABET_PATH)/build
ALPHABET_CPP = $(ALPHABET_PATH)/cpp
ALPHABET_HPP = $(ALPHABET_PATH)/include
ALPHABET_PONY_SOURCE = $(ALPHABET_PATH)/alphabet-app

build-book-examples-cpp-alphabet-cpp-all = build-cpp_api-all alphabet_cpp_clean alphabet_cpp_build
test-book-examples-cpp-alphabet-cpp-all = build-book-examples-cpp-alphabet-cpp-all alphabet_cpp_test
clean-book-examples-cpp-alphabet-cpp-all = alphabet_cpp_clean

alphabet_cpp_build:
	mkdir -p $(ALPHABET_BUILD)
	c++ --debug -c -o $(ALPHABET_BUILD)/alphabet.o $(ALPHABET_CPP)/alphabet.cpp -Wall -std=c++11 -I$(ALPHABET_HPP) -I$(WALLAROO_CPP_INCLUDE)
	ar rs $(ALPHABET_BUILD)/libalphabet.a $(ALPHABET_BUILD)/alphabet.o
	ponyc $(PONY_LINKER) --debug --export --output=$(ALPHABET_BUILD) --path $(WALLAROO_LIB):$(CPP_PONY_LIB):$(WALLAROO_CPP_LIB):$(ALPHABET_BUILD) $(ALPHABET_PONY_SOURCE)

alphabet_cpp_clean:
	rm -rf $(ALPHABET_BUILD)

alphabet_cpp_test:
	$(QUIET)echo "alphabet-cpp tests"

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

