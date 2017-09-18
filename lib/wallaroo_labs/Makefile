# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false

LIB_WALLAROO_LABS_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

test-lib-wallaroo_labs: lib_wallaroo_labs_test

lib_wallaroo_labs_test:
	cd $(abspath $(LIB_WALLAROO_LABS_PATH:%/=%)) && ./$(notdir $(abspath $(LIB_WALLAROO_LABS_PATH:%/=%))) --sequential

# end of prevent rules from being evaluated/included multiple times
endif
