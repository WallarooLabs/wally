# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

ROOT_MAKEFILE_MK := 1
ROOT_MAKEFILE := $(lastword $(MAKEFILE_LIST))
ROOT_MAKEFILE_PATH := $(dir $(ROOT_MAKEFILE))
rules_mk_path := $(ROOT_MAKEFILE_PATH)/rules.mk

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false

# standard rules generation makefile
include $(rules_mk_path)

# end of prevent rules from being evaluated/included multiple times
endif
