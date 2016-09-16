rules_mk_path := ../../rules.mk

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false



#########################################################################################
#### don't change after this line unless to disable standard rules generation makefile
MY_NAME := $(lastword $(MAKEFILE_LIST))
$(MY_NAME)_PATH := $(dir $(MY_NAME))

include $($(MY_NAME)_PATH:%/=%)/$(rules_mk_path)
#### don't change before this line unless to disable standard rules generation makefile
#########################################################################################


# args to RUN_DAGON and RUN_DAGON_SPIKE: $1 = test name; $2 = ini file; $3 = timeout; $4 = wesley test command, $5 = include in CI
# NOTE: all paths must be relative to buffy directory (use buffy_path variable)

#dagon-identity: #used as part of `make help` command ## Run identity test with dagon
$(eval $(call RUN_DAGON\
,dagon-identity \
,$(buffy_path)/apps/double-divide/double-divide.ini \
,15 \
,$(buffy_path)/wesley/identity-test/identity-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,true))

#dagon-identity-drop: #used as part of `make help` command ## Run identity drop test with dagon
$(eval $(call RUN_DAGON_SPIKE\
,dagon-identity-drop \
,$(buffy_path)/apps/double-divide/double-divide-drop.ini \
,15 \
,$(buffy_path)/wesley/identity-test/identity-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,true))

