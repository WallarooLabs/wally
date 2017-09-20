# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../Makefile
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

# standard rules generation makefile
# include $(rules_mk_path)

# #
# CPPAPI_PATH = $(wallaroo_path)/cpp_api/cpp/cppapi
# CPPAPI_BUILD_PATH = $(CPPAPI_PATH)/build

# build-cpp_api: cpp_api_clean cpp_api_build
# test-cpp_api: build-cpp_api
# clean-cpp_api = cpp_api_clean

# cpp_api_build:
# 	mkdir -p $(CPPAPI_BUILD_PATH)
# 	cd $(CPPAPI_BUILD_PATH) && cmake -DCMAKE_INSTALL_PREFIX=/tmp/cpp_api ..
# 	cd $(CPPAPI_BUILD_PATH) && make
# 	cd $(CPPAPI_BUILD_PATH) && make install/local

# cpp_api_clean:
# 	rm -rf $(CPPAPI_BUILD_PATH)

# cpp_api_test:
# 	$(QUIET)echo "cpp_api tests"

# end of prevent rules from being evaluated/included multiple times
endif
