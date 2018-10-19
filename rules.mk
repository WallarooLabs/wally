# Based on:
# https://mischasan.wordpress.com/2013/03/30/non-recursive-make-gmake-part-1-the-basic-gnumakefile-layouts/
# https://github.com/mischasan/aho-corasick/blob/master/rules.mk
# https://github.com/dmoulding/boilermake/blob/master/Makefile
#
# With optimizations from:
# http://www.oreilly.com/openbook/make3/book/ch12.pdf
#
# More advanced functionality should likely use:
# http://gmsl.sourceforge.net/

# detemine makefile that included this one and it's path
PREV_MAKEFILE := $(word $(words $(MAKEFILE_LIST)),x $(MAKEFILE_LIST))
PREV_PATH := $(dir $(PREV_MAKEFILE))
ABS_PREV_MAKEFILE := $(abspath $(PREV_MAKEFILE))

# prevent rules from being evaluated/included multiple times
ifndef RULES_MK
RULES_MK := 1

# path of rules.mk file
RULES_MK_PATH := $(dir $(lastword $(MAKEFILE_LIST)))

# path of original makefile
ROOT_MAKEFILE := $(word 1, $(MAKEFILE_LIST))
ROOT_PATH := $(dir $(ROOT_MAKEFILE))

# if debug shell command output requested
ifdef DEBUG_SHELL
 SHELL = /bin/sh -x
endif

# if verbose output not requested
ifndef VERBOSE
 QUIET := @
endif

# set wallaroo project directory
wallaroo_dir := $(RULES_MK_PATH)
abs_wallaroo_dir := $(abspath $(wallaroo_dir))
wallaroo_path := $(abs_wallaroo_dir)

# Set global path variables
integration_path := $(wallaroo_path)/testing/tools
integration_bin_path := $(integration_path)
wallaroo_lib :=  $(wallaroo_path)/lib
wallaroo_python_path := $(wallaroo_path)/machida/lib
machida_bin_path := $(wallaroo_path)/machida/build
machida3_bin_path := $(wallaroo_path)/machida3/build
external_sender_bin_path := $(integration_path)/external_sender

EMPTY :=
SPACE := $(EMPTY) $(EMPTY)

ORIGINAL_PYTHONPATH := $(PYTHONPATH)
FIXED_PYTHONPATH := .:$(integration_path):$(wallaroo_python_path)
export PYTHONPATH = $(ORIGINAL_PYTHONPATH):$(FIXED_PYTHONPATH):$(subst :$(SPACE),:,$(subst $(SPACE):,:,$(strip $(CUSTOM_PYTHONPATH))))

ORIGNAL_PATH := $(PATH)
FIXED_PATH := $(integration_bin_path):$(machida_bin_path):$(machida3_bin_path):$(external_sender_bin_path)
export PATH = $(ORIGNAL_PATH):$(FIXED_PATH):$(subst :$(SPACE),:,$(subst $(SPACE):,:,$(strip $(CUSTOM_PATH))))

# initialize default for some normal targets and variables
build-wallarooroot-all :=
test-wallarooroot-all :=
unit-tests-wallarooroot-all :=
integration-tests-wallarooroot-all :=
clean-wallarooroot-all :=
build-docker-wallarooroot-all :=
push-docker-wallarooroot-all :=

ifndef ponyc_docker_args
  ponyc_docker_args :=
endif

ifndef monhub_docker_args
  monhub_docker_args :=
endif

ifndef quote
  quote :=
endif

ifndef ponyc_arch_args
  ponyc_arch_args :=
endif

wallaroo_version = $(shell cat $(ROOT_PATH)/VERSION)

# function to lazily initialize a variable on first use and to only evaluate the expression once
# see: http://www.oreilly.com/openbook/make3/book/ch10.pdf
# $(call lazy-init,variable-name,value)
define lazy-init
 $1 = $$(redefine-$1) $$($1)
 redefine-$1 = $$(eval $1 := $2)
endef

# function to check value of a variable is one of a list of valid values
define check-values
$(if $(filter $($(1)),$(2)),,\
  $(error Unknown $(1) option "$($(1))". Valid values are "$(2)".))
endef

# how to get the latest ponyc tag
latest_ponyc_tag_src = $(shell curl -s \
  https://hub.docker.com/r/wallaroolabs/ponyc/tags/ | grep -o \
  'wallaroolabs-[0-9.-]*-' | sed 's/wallaroolabs-\([0-9.-]*\)-/\1/' \
  | sort -un | tail -n 1)# latest ponyc tag

# latest_ponyc_tag - a lazy init of latest_ponyc_tag (will only be evaluated if used)
$(eval \
  $(call lazy-init,latest_ponyc_tag,\
    $$(call latest_ponyc_tag_src)))

docker_image_version_src = $(shell git describe --tags --always)# Docker Image Tag to use

# docker_image_version_val - a lazy init of docker_image_version_val (will only be evaluated if used)
$(eval \
  $(call lazy-init,docker_image_version_val,\
    $$(call docker_image_version_src)))

DEBUG_SHELL ?= ## Debug shell commands?
VERBOSE ?= ## Print commands as they're executed?
docker_image_version ?= $(strip $(docker_image_version_val))## Docker Image Tag to use
docker_image_repo_host ?= ## Docker Repository to use
docker_image_repo ?= $(docker_image_repo_host)wallaroolabs## Docker Repository to use
arch ?= native## Architecture to build for
in_docker ?= false## Whether already in docker or not (used by CI)
ponyc_tag ?= wallaroolabs-$(strip $(latest_ponyc_tag))-release## tag for ponyc docker to use
ponyc_runner ?= wallaroolabs/ponyc## ponyc docker image to use
pytest_exp ?= ## Additional args to pass pytests run with make test
debug ?= false## Use ponyc debug option (-d)
debug_arg :=# Final argument string for debug option
trace ?= false## Use ponyc -D trace flag for Wallaroo
trace_arg :=# Final argument string for trace option
spike ?= false## Enable compile-time network fault injection
spike_arg :=# Final argument string for spike option
docker_host ?= $(DOCKER_HOST)## docker host to build/run containers on
ifeq ($(docker_host),)
  docker_host := unix:///var/run/docker.sock
endif
docker_host_arg := --host=$(docker_host)# docker host argument
monhub_builder ?= monitoring-hub-builder
monhub_builder_tag ?= 2.0
unix_timestamp := $(shell date +%s) # unix timestamp for docker network name
demo_cluster_name ?= ## Name of demo cluster
demo_cluster_spot_pricing ?= true## Whether to use spot pricing or not for demo cluster
autoscale ?= on## Build with Autoscale or not
clustering ?= on## Build with Clustering or not
resilience ?= off## Build with Resilience or not
PONYCC ?= ponyc## Path to ponyc executable
PONYSTABLE ?= stable## Path to pony stable executable
target_cpu ?= ## Target CPU to generate binary for

ifneq ($(target_cpu),)
  target_cpu_arg := --cpu $(target_cpu)
endif

# validation of variable
ifdef autoscale
  $(eval $(call check-values,autoscale,on off))
endif

ifeq ($(autoscale),on)
  autoscale_arg := -D autoscale
endif

# validation of variable
ifdef clustering
  $(eval $(call check-values,clustering,on off))
endif

ifeq ($(clustering),on)
  clustering_arg := -D clustering
endif

# validation of variable
ifdef resilience
  $(eval $(call check-values,resilience,on off))
endif

ifeq ($(resilience),on)
  resilience_arg := -D resilience
endif

# validation of variable
ifdef demo_cluster_spot_pricing
  $(eval $(call check-values,demo_cluster_spot_pricing,false true))
endif

# validation of variable
ifdef debug
  $(eval $(call check-values,debug,false true))
endif

ifeq ($(shell uname -s),Linux)
  extra_xargs_arg := -r
  docker_user_arg := -u `id -u`:`id -g`
  host_ip_src = $(shell ifconfig `route -n | grep '^0.0.0.0' | awk '{print $$8}'` | egrep -o 'inet addr:[^ ]+' | awk -F: '{print $$2}')
  system_cpus := $(shell which cset > /dev/null && sudo cset set -l -r | grep '/system' | awk '{print $$2}')
  ifneq (,$(system_cpus))
    docker_cpu_arg := --cpuset-cpus $(system_cpus)
  endif
else
  host_ip_src = $(shell ifconfig `route -n get 0.0.0.0 2>/dev/null | awk '/interface: / {print $$2}'` | egrep -o 'inet [^ ]+' | awk '{print $$2}')
endif

# host_ip - a lazy init of host_ip (will only be evaluated if used)
$(eval \
  $(call lazy-init,host_ip,\
    $$(call host_ip_src)))

ifeq ($(debug),true)
  debug_arg := --debug
endif

ifeq ($(trace),true)
  trace_arg := -D trace
endif

ifeq ($(spike), true)
	spike_arg := -D spike
endif

# validation of variable
ifdef arch
  $(eval $(call check-values,arch,amd64 native))
endif

# validation of variable
ifdef in_docker
  $(eval $(call check-values,in_docker,false true))
endif

# additional ponyc arguments when building for armhf
ifeq ($(arch),armhf)
  ponyc_arch_args := --triple arm-unknown-linux-gnueabihf --link-arch armv7-a \
                       --linker arm-linux-gnueabihf-gcc
endif

# only set docker arguments if building for a non-native platform and not in docker
ifneq ($(arch),native)
  ifneq ($(in_docker),true)
    quote = '
    ponyc_docker_args = docker run --rm -i $(docker_user_arg) -v \
        $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
        $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
        $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
        $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
        $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
        -w $(1) --entrypoint bash \
        $(ponyc_runner):$(ponyc_tag) -c $(quote)

    monhub_docker_args = docker run --rm -i -v \
        $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
        $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
        $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
        $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
        $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
        -w $(1) --entrypoint bash \
        $(docker_image_repo)/$(monhub_builder):$(monhub_builder_tag) -c $(quote)
  endif
endif

# function call for compiling with ponyc and generating dependency info
define PONYC
  $(QUIET)cd $(1) && $(ponyc_docker_args) $(PONYSTABLE) fetch \
    $(if $(filter $(ponyc_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(ponyc_docker_args) $(PONYSTABLE) env $(PONYCC) $(ponyc_arch_args) \
    $(debug_arg) $(spike_arg) $(trace_arg) $(autoscale_arg) $(clustering_arg) $(resilience_arg) \
    $(PONYCFLAGS) $(EXTRA_PONYCFLAGS) $(target_cpu_arg) --features=-avx512f . $(if $(filter $(ponyc_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && echo "$@: $(wildcard $(abspath $(1))/bundle.json)" | tr '\n' ' ' > $(notdir $(abspath $(1:%/=%))).d
  $(QUIET)cd $(1) && $(ponyc_docker_args) $(PONYSTABLE) env $(PONYCC) $(ponyc_arch_args) \
    $(debug_arg) $(spike_arg) $(trace_arg) $(autoscale_arg) $(clustering_arg) $(resilience_arg) \
    $(PONYCFLAGS) $(EXTRA_PONYCFLAGS) $(target_cpu_arg) --features=-avx512f . --pass import --files $(if $(filter \
    $(ponyc_docker_args),docker),$(quote)) 2>/dev/null | grep -o "$(abs_wallaroo_dir).*.pony" \
    | awk 'BEGIN { a="" } {a=a$$1":\n"; printf "%s ",$$1} END {print "\n"a}' \
    >> $(notdir $(abspath $(1:%/=%))).d
  $(QUIET)cd $(1) && echo $(if $(wildcard $(abspath $(1))/bundle.json),"$(abspath $(1))/bundle.json:",) >> $(notdir $(abspath $(1:%/=%))).d
endef

# function call for compiling monhub projects
define MONHUBC
  $(QUIET)cd $(1) && $(monhub_docker_args) mix local.hex --force \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) mix local.rebar --force \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) mix deps.get \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) mix compile \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
endef

# function call for compiling ui projects for release
define MONHUBR
  $(QUIET)cd $(1) && $(monhub_docker_args) mix local.hex --force \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) mix local.rebar --force \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) if [ -d "_build" ]; then MIX_ENV=prod mix deps.clean --build --all; fi \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) MIX_ENV=prod mix deps.get --only prod \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) MIX_ENV=prod mix compile \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) npm uninstall \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) npm install node-sass babelify browserify \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) npm install \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) WALLAROO_VERSION=$(wallaroo_version) npm run build:production \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) MIX_ENV=prod mix phx.digest \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) MIX_ENV=prod mix release.clean \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  $(QUIET)cd $(1) && $(monhub_docker_args) MIX_ENV=prod mix release \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
endef

# rule to generate includes for makefiles in subdirs of first argument
define make-goal
$(eval MAKEDIRS := $(sort $(dir $(wildcard $(1:%/=%)/*/Makefile))))
$(eval MAKEFILES := $(sort $(wildcard $(1:%/=%)/*/Makefile)))
$(foreach mdir,$(MAKEDIRS),$(eval $(notdir $(mdir:%/=%)) := $(mdir)))
$(eval include $(MAKEFILES))
endef

# rule to generate targets for building actual pony executable including dependencies to relevant *.pony files so incremental builds work properly
define ponyc-goal
# include dependencies for already compiled executables
-include $(abspath $(1:%/=%))/$(notdir $(abspath $(1:%/=%))).d
$(abspath $(1:%/=%))/$(notdir $(abspath $(1:%/=%))):
	$$(call PONYC,$(abspath $(1:%/=%)))
endef

.PHONY: build-pony-all build-docker-pony-all push-docker-pony-all test-pony-all clean-pony-all

# rule to generate targets for build-* for devs to use
define pony-build-goal
build-pony-all: build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-docker-pony-all: build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
push-docker-pony-all: push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): $(abspath $(1:%/=%))/$(notdir $(abspath $(1:%/=%)))
.PHONY: build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all
endef

# rule to add `build-testing-tools-external_sender` to all integrtion-test commands
define integration-tests-external_sender-goal
integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): build-testing-tools-external_sender build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
endef

# rule to generate targets for test-* for devs to use
define pony-test-goal
test-pony-all: test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
ifneq ($($(ABS_PREV_MAKEFILE)_UNIT_TEST_COMMAND),false)
	cd $(abspath $(1:%/=%)) && ./$(notdir $(abspath $(1:%/=%)))
endif
integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
.PHONY: test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
endef

# rule to generate targets for clean-* for devs to use
define pony-clean-goal
clean-pony-all: clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))):
	$(QUIET)rm -f $(abspath $1)/$(notdir $(abspath $(1:%/=%))) $(abspath $1)/$(notdir $(abspath $(1:%/=%))).o
	$(QUIET)rm -f $(abspath $1)/$(notdir $(abspath $(1:%/=%))).d
	$(QUIET)rm -rf $(abspath $1)/.deps
	$(QUIET)rm -rf $(abspath $1)/$(notdir $(abspath $(1:%/=%))).dSYM
.PHONY: clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all
endef

# rule to generate targets for building actual monhub executable including dependencies to relevant files so incremental builds work properly
define monhub-goal
$(abspath $(1:%/=%))/../../_build/dev/lib/$(notdir $(abspath $(1:%/=%)))/ebin/$(notdir $(abspath $(1:%/=%))).app: $(shell find $(wildcard $(abspath $1)/config) $(wildcard $(abspath $1)/lib) $(wildcard $(abspath $1)/mix.exs) $(wildcard $(abspath $1)/priv) $(wildcard $(abspath $1)/web) $(wildcard $(abspath $1)/package.json) -type f)
	$$(call MONHUBC,$(abspath $(1:%/=%)))
endef

# rule to generate targets for building actual monhub executable including dependencies to relevant files so incremental builds work properly
define monhub-release-goal
$(abspath $(1:%/=%))/_build/prod/rel/$(notdir $(abspath $(1:%/=%)))/bin/$(notdir $(abspath $(1:%/=%))): $(shell find $(wildcard $(abspath $1)/config) $(wildcard $(abspath $1)/lib) $(wildcard $(abspath $1)/mix.exs) $(wildcard $(abspath $1)/priv) $(wildcard $(abspath $1)/web) $(wildcard $(abspath $1)/package.json) -type f)
	$$(call MONHUBR,$(abspath $(1:%/=%)))
release-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): monhub-arch-check $(abspath $(1:%/=%))/_build/prod/rel/$(notdir $(abspath $(1:%/=%)))/bin/$(notdir $(abspath $(1:%/=%)))
release-monhub-all: release-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
.PHONY: release-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
endef

.PHONY: build-monhub-all build-docker-monhub-all push-docker-monhub-all test-monhub-all clean-monhub-all release-monhub-all

# rule to generate targets for build-* for devs to use
define monhub-build-goal
build-monhub-all: build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-docker-monhub-all: build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
push-docker-monhub-all: push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): $(abspath $(1:%/=%))/../../_build/dev/lib/$(notdir $(abspath $(1:%/=%)))/ebin/$(notdir $(abspath $(1:%/=%))).app
.PHONY: build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all
endef

# rule to generate targets for test-* for devs to use
define monhub-test-goal
test-monhub-all: test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
ifneq ($($(ABS_PREV_MAKEFILE)_UNIT_TEST_COMMAND),false)
	cd $(abspath $(1:%/=%)) && mix test
endif
.PHONY: test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
endef

# rule to generate targets for clean-* for devs to use
define monhub-clean-goal
clean-monhub-all: clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))):
	$(QUIET)rm -rf $(abspath $1)/node_modules
	$(QUIET)rm -rf $(abspath $1)/_build
	$(QUIET)rm -rf $(abspath $1)/priv/static
	$(QUIET)rm -rf $(abspath $1)/../../deps
	$(QUIET)rm -rf $(abspath $1)/../../_build
.PHONY: clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))) clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all
endef

# rule to generate targets for build-docker-* for devs to use
define build-docker-goal
build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): docker-arch-check $(if $(wildcard $(PREV_PATH)/package.json),release-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))),)
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))).$(arch):$(docker_image_version) \
          $(abspath $1)
.PHONY: build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
endef

# rule to generate targets for push-docker-* for devs to use
define push-docker-goal
push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all += push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))): build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
	docker $(docker_host_arg) push \
          $(docker_image_repo)/$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1))).$(arch):$(docker_image_version)
.PHONY: push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))
endef

# rule to generate targets for *-all for devs to use
define subdir-goal
$(eval MY_TARGET_SUFFIX := $(if $(filter $(abs_wallaroo_dir),$(abspath $1)),wallarooroot-all,$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all))

$(eval build-$(MY_TARGET_SUFFIX:%-all=%):)
$(eval test-$(MY_TARGET_SUFFIX:%-all=%):)
$(eval unit-tests-$(MY_TARGET_SUFFIX:%-all=%):)
$(eval integration-tests-$(MY_TARGET_SUFFIX:%-all=%):)
$(eval clean-$(MY_TARGET_SUFFIX:%-all=%):)
$(eval build-$(MY_TARGET_SUFFIX): build-$(MY_TARGET_SUFFIX:%-all=%) $(build-$(MY_TARGET_SUFFIX)))
$(eval test-$(MY_TARGET_SUFFIX): test-$(MY_TARGET_SUFFIX:%-all=%) $(test-$(MY_TARGET_SUFFIX)))
$(eval unit-tests-$(MY_TARGET_SUFFIX): unit-tests-$(MY_TARGET_SUFFIX:%-all=%) $(unit-tests-$(MY_TARGET_SUFFIX)))
$(eval integration-tests-$(MY_TARGET_SUFFIX): integration-tests-$(MY_TARGET_SUFFIX:%-all=%) $(integration-tests-$(MY_TARGET_SUFFIX)))
$(eval clean-$(MY_TARGET_SUFFIX): clean-$(MY_TARGET_SUFFIX:%-all=%) $(clean-$(MY_TARGET_SUFFIX)))

$(eval build-docker-$(MY_TARGET_SUFFIX): $(build-docker-$(MY_TARGET_SUFFIX)))
$(eval push-docker-$(MY_TARGET_SUFFIX): $(push-docker-$(MY_TARGET_SUFFIX)))

.PHONY: build-$(MY_TARGET_SUFFIX) test-$(MY_TARGET_SUFFIX) unit-tests-$(MY_TARGET_SUFFIX) integration-tests-$(MY_TARGET_SUFFIX) clean-$(MY_TARGET_SUFFIX) build-docker-$(MY_TARGET_SUFFIX) push-docker-$(MY_TARGET_SUFFIX)
endef

# rule to generate targets for *-all for devs to use
define subdir-recurse-goal
$(eval MAKEDIRS := $(sort $(dir $(wildcard $(1:%/=%)/*/Makefile))))
$(eval MY_TARGET_SUFFIX := $(if $(filter $(abs_wallaroo_dir),$(abspath $1)),wallarooroot-all,$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $1)))-all))
$(foreach mdir,$(MAKEDIRS),$(eval build-$(MY_TARGET_SUFFIX) += build-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
$(foreach mdir,$(MAKEDIRS),$(eval test-$(MY_TARGET_SUFFIX) += test-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
$(foreach mdir,$(MAKEDIRS),$(eval unit-tests-$(MY_TARGET_SUFFIX) += unit-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
$(foreach mdir,$(MAKEDIRS),$(eval integration-tests-$(MY_TARGET_SUFFIX) += integration-tests-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
$(foreach mdir,$(MAKEDIRS),$(eval clean-$(MY_TARGET_SUFFIX) += clean-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
$(foreach mdir,$(MAKEDIRS),$(eval build-docker-$(MY_TARGET_SUFFIX) += build-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
$(foreach mdir,$(MAKEDIRS),$(eval push-docker-$(MY_TARGET_SUFFIX) += push-docker-$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(mdir))))-all))
endef

ROOT_TARGET_SUFFIX := $(if $(filter $(abs_wallaroo_dir),$(abspath $(ROOT_PATH))),wallarooroot-all,$(subst /,-,$(subst $(abs_wallaroo_dir)/,,$(abspath $(ROOT_PATH))))-all)

# phony targets
.PHONY: build build-docker build-monhub build-pony clean clean-docker clean-monhub clean-pony list push-docker test-monhub test-pony test docker-arch-check monhub-arch-check help build-docker-pony push-docker-pony build-docker-monhub push-docker-monhub

# default targets
.DEFAULT_GOAL := build
build: build-$(ROOT_TARGET_SUFFIX) ## Build all projects (pony & monhub) (DEFAULT)
test: unit-tests integration-tests ## Test all projects (pony & monhub)
unit-tests: unit-tests-$(ROOT_TARGET_SUFFIX) ## Test all projects (pony & monhub)
integration-tests: integration-tests-$(ROOT_TARGET_SUFFIX) ## Test all projects (pony & monhub)
build-pony: build-pony-all ## Build all pony projects
test-pony: test-pony-all ## Test all pony projects
clean-pony: clean-pony-all ## Clean all pony projects
build-docker-pony: build-docker-pony-all ## Build docker containers for all pony projects
push-docker-pony: push-docker-pony-all ## Push docker containers for all pony projects
build-monhub: build-monhub-all ## Build all monhub projects
release-monhub: release-monhub-all ## Create release packages for all monhub projects
test-monhub: test-monhub-all ## Test all monhub projects
clean-monhub: clean-monhub-all ## Clean all monhub projects
build-docker-monhub: build-docker-monhub-all ## Build docker containers for all monhub projects
push-docker-monhub: push-docker-monhub-all ## Push docker containers for all monhub projects
build-docker: build-docker-$(ROOT_TARGET_SUFFIX) ## Build all docker images
push-docker: push-docker-$(ROOT_TARGET_SUFFIX) ## Push all docker images

# rule to print info about make variables, works only with make 3.81 and above
# to use invoke make with a target of print-VARNAME, e.g.,
# make print-CCFLAGS
print-%:
	$(QUIET)echo '$*=$($*)'
	$(QUIET)echo '  origin = $(origin $*)'
	$(QUIET)echo '  flavor = $(flavor $*)'
	$(QUIET)echo '   value = $(value  $*)'


# rule to build wallaroo source archive
.PHONY: build-wallaroo-source-archive
ifeq ($(shell uname -s),Linux)
build-wallaroo-source-archive:
	$(QUIET)cd $(wallaroo_path) && \
          tar --transform "flags=r;s|^|wallaroo/|" -czf "wallaroo.tgz" ./*
else
build-wallaroo-source-archive:
	$(QUIET)cd $(wallaroo_path) && \
          mkdir /tmp/wallaroo && \
          cp -r ./* /tmp/wallaroo && \
          cd /tmp && \
          tar -czf "$(wallaroo_path)/wallaroo.tgz" wallaroo && \
          rm -rf wallaroo
endif


define METRICS_UI_DESKTOP_HEREDOC
[Desktop Entry]
Name=Wallaroo Metrics UI
Icon=metrics_ui
Type=Application
NoDisplay=true
Exec=metrics_reporter_ui
Terminal=true
Categories=Development;
endef


define APPRUN_HEREDOC
#!/bin/sh
HERE=$$(dirname "$$(readlink -f "$${0}")")
"$${HERE}"/usr/bin/metrics_reporter_ui $$@
if [ "$$1" = "start" ]; then
  sleep 4
fi
if [ "$$1" = "stop" ]; then
  PID_TO_KILL=$$(ps aux | grep '/usr/erts-9.1/bin/epmd' | grep -v grep | awk '{print $$2}')
  if [ "$$PID_TO_KILL" != "" ]; then
    kill $$PID_TO_KILL
  fi
fi
endef


export APPRUN_HEREDOC
export METRICS_UI_DESKTOP_HEREDOC

# rule to build metrics_ui appimage
.PHONY: build-metrics-ui-appimage
build-metrics-ui-appimage:
## Build Metrics UI if not already built
	$(QUIET)cd $(wallaroo_path) && \
          mkdir -p metrics_ui.AppDir/usr/

	$(QUIET)cd $(wallaroo_path) && \
	  echo "$$METRICS_UI_DESKTOP_HEREDOC" >> ./metrics_ui.desktop

	$(QUIET)cd $(wallaroo_path) && \
	  echo "$$APPRUN_HEREDOC" >> ./AppRun

	$(QUIET)cd $(wallaroo_path) && \
          chmod a+x ./AppRun

	$(QUIET)cd $(wallaroo_path) && \
          curl https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage -o linuxdeploy-x86_64.AppImage -J -L
	$(QUIET)cd $(wallaroo_path) && \
          chmod +x linuxdeploy-x86_64.AppImage

# set up icon/logo for appimage
	$(QUIET)cd $(wallaroo_path) && \
          cp .release/metrics_ui_appimage_icon.png metrics_ui.png

# can't run appimages in docker; need to extract and then run
	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "./linuxdeploy-x86_64.AppImage --appimage-extract"

# need to run in CentOS 7 docker image
	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -v /etc/passwd:/etc/passwd:ro \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c 'export HOME=/tmp && mkdir /tmp/.nvm && curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | NVM_DIR="/tmp/.nvm" bash && export NVM_DIR="/tmp/.nvm" && [ -s "$$NVM_DIR/nvm.sh" ] && . "$$NVM_DIR/nvm.sh" && nvm install node && nvm alias default node && make release-monitoring_hub-apps-metrics_reporter_ui'

# put files into AppDir
	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "cd metrics_ui.AppDir/usr && tar -xvzf ../../monitoring_hub/apps/metrics_reporter_ui/_build/prod/rel/metrics_reporter_ui/releases/0.0.1/metrics_reporter_ui.tar.gz"

# build appimage
	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "ARCH=x86_64 ./squashfs-root/AppRun --appdir metrics_ui.AppDir --custom-apprun=AppRun --desktop-file=metrics_ui.desktop --icon-file=metrics_ui.png -l /usr/lib64/libtinfo.so.5"

## temporary hack; remove once linuxdeploy works correctly
# no user arg to docker because yum needs to run as root
	$(QUIET)docker run --rm -i -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "yum install patchelf -y && patchelf --set-rpath '\$$ORIGIN/../../lib' metrics_ui.AppDir/usr/erts-9.1/bin/beam.smp"

## temporary hack; remove once linuxdeploy works correctly
	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "mv metrics_ui.AppDir/usr/lib/libcrypto.so.10 metrics_ui.AppDir/usr/lib/crypto-4.1/priv/lib/"

	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "ARCH=x86_64 ./squashfs-root/AppRun --appdir metrics_ui.AppDir --custom-apprun=AppRun --desktop-file=metrics_ui.desktop --icon-file=metrics_ui.png --output appimage"

	$(QUIET)cd $(wallaroo_path) && \
          rm linuxdeploy-x86_64.AppImage
	$(QUIET)cd $(wallaroo_path) && \
          sh -c "rm -rf squashfs-root"
	$(QUIET)docker run --rm -i $(docker_user_arg) -v \
          $(abs_wallaroo_dir):$(abs_wallaroo_dir) $(docker_cpu_arg) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/root/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.gitconfig),-v $(HOME)/.gitconfig:/$(HOME)/.gitconfig,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/root/.git-credential-cache,) \
          $(if $(wildcard -v $(HOME)/.git-credential-cache),-v $(HOME)/.git-credential-cache:/$(HOME)/.git-credential-cache,) \
          -w $(abs_wallaroo_dir) \
          wallaroolabs/metrics_ui-centos-builder:2018.08.03.1 \
          sh -c "rm -rf metrics_ui.AppDir"
	$(QUIET)cd $(wallaroo_path) && \
          rm AppRun
	$(QUIET)cd $(wallaroo_path) && \
          rm metrics_ui.desktop
	$(QUIET)cd $(wallaroo_path) && \
          rm metrics_ui.png

# rule to confirm we are building for a real docker architecture we support
docker-arch-check:
	$(if $(filter $(arch),native),$(error Arch cannot be 'native' \
          for docker build!),)

# rule to confirm we are building for a real monitoring architecture we support
monhub-arch-check:
	$(if $(filter $(arch),armhf),$(error Arch cannot be 'armhf' \
          for building of monitoring hub!),)

# different types of docker images
exited = $(shell docker $(docker_host_arg) ps -a -q -f status=exited)
untagged = $(shell (docker $(docker_host_arg) images | grep "^<none>" | awk \
              -F " " '{print $$3}'))
dangling = $(shell docker $(docker_host_arg) images -f "dangling=true" -q)
tag = $(shell docker $(docker_host_arg) images | grep \
         "$(docker_image_version)" | awk -F " " '{print $$1 ":" $$2}')

# rule to clean up docker images/containers
clean-docker: ## cleanup docker images and containers
	$(if $(strip $(exited)),$(QUIET)echo "Cleaning exited containers: $(exited)",)
	$(if $(strip $(exited)),$(QUIET)docker $(docker_host_arg) rm -v $(exited),)
	$(if $(strip $(tag)),$(QUIET)echo "Removing tag $(tag) image",)
	$(if $(strip $(tag)),$(QUIET)docker $(docker_host_arg) rmi $(tag),)
	$(if $(strip $(dangling)),$(QUIET)echo "Cleaning dangling images: $(dangling)",)
	$(if $(strip $(dangling)),$(QUIET)docker $(docker_host_arg) rmi $(dangling),)

# rule to clean everything
clean: clean-$(ROOT_TARGET_SUFFIX) ## Clean all projects (pony & monhub) and cleanup docker images
	$(QUIET)rm -f $(abs_wallaroo_dir)/wallaroo.tgz $(abs_wallaroo_dir)/Wallaroo_Metrics_UI-x86_64.AppImage $(abs_wallaroo_dir)/linuxdeploy-x86_64.AppImage
	$(QUIET)rm -rf $(abs_wallaroo_dir)/squashfs-root $(abs_wallaroo_dir)/metrics_ui.AppDir
	$(QUIET)rm -f $(abs_wallaroo_dir)/AppRun $(abs_wallaroo_dir)/metrics_ui.desktop $(abs_wallaroo_dir)/metrics_ui.png
	$(QUIET)rm -f lib/wallaroo/wallaroo lib/wallaroo/wallaroo.o
	$(QUIET)rm -f sent.txt received.txt
	$(QUIET)echo 'Done cleaning.'

list: ## List all targets (including automagically generated ones)
	$(QUIET)$(MAKE) -pRrq -f $(lastword $(MAKEFILE_LIST)) : 2>/dev/null | awk -v RS= -F: '/^# File/,/^# Finished Make data base/ {if ($$1 !~ "^[#.]") {print $$1}}' | sort | egrep -v -e '^[^[:alnum:]]' -e '^$@$$'

help: ## this help message
	$(QUIET)echo 'Usage: make [option1=value] [option2=value,...] [target]'
	$(QUIET)echo ''
	$(QUIET)echo 'Options:'
	$(QUIET)grep -h -E '^[a-zA-Z0-9_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | sort -u | awk \
          'BEGIN {FS = "\\?="}; {printf "\033[36m%-40s\033[0m ##%s\n", $$1, \
          $$2}' | awk 'BEGIN {FS = "## "}; {printf "%s%s \033[36m(Default:\
 %s)\033[0m\n", $$1, $$3, $$2}'
	$(QUIET)grep -h -E 'ifeq.*filter.*\)$$' $(MAKEFILE_LIST) | sort -u | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-40s\033[0m %s\n", \
          " Valid values for " $$5 ":", $$7}'
	$(QUIET)echo ''
	$(QUIET)echo 'Targets:'
	$(QUIET)echo "\033[36m{command}-{dir}-all                      \033[0mRun command for a directory and all it's sub-projects."
	$(QUIET)echo "                                         Where command is one of: build,test,clean,build-docker,push-docker"
	$(QUIET)grep -h -E '^[a-zA-Z0-9_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort -u | awk \
          'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-40s\033[0m %s\n", \
          $$1, $$2}'

endif # RULES_MK

# check control variables for valid values
$(evel $(call check-values,$(ABS_PREV_MAKEFILE)_UNIT_TEST_COMMAND,false true))
$(evel $(call check-values,$(ABS_PREV_MAKEFILE)_PONY_TARGET,false true))
$(evel $(call check-values,$(ABS_PREV_MAKEFILE)_PONYC_TARGET,false true))
$(evel $(call check-values,$(ABS_PREV_MAKEFILE)_DOCKER_TARGET,false true))
$(evel $(call check-values,$(ABS_PREV_MAKEFILE)_EXS_TARGET,false true))
$(evel $(call check-values,$(ABS_PREV_MAKEFILE)_RECURSE_SUBMAKEFILES,false true))

# if there's a pony source file, create the appropriate rules for it unless disabled
ifneq ($($(ABS_PREV_MAKEFILE)_PONY_TARGET),false)
  ifneq ($(wildcard $(PREV_PATH)/*.pony),)
    ifneq ($($(ABS_PREV_MAKEFILE)_PONYC_TARGET),false)
      $(eval $(call ponyc-goal,$(PREV_PATH)))
    endif
    $(eval $(call pony-build-goal,$(PREV_PATH)))
    $(eval $(call pony-test-goal,$(PREV_PATH)))
    $(eval $(call pony-clean-goal,$(PREV_PATH)))
  endif
endif

# Add external_sender dependency to integration-tests-*
$(eval $(call integration-tests-external_sender-goal,$(PREV_PATH)))

# if there's a exs source file, create the appropriate rules for it unless disabled
ifneq ($($(ABS_PREV_MAKEFILE)_EXS_TARGET),false)
  ifneq ($(wildcard $(PREV_PATH)/*.exs),)
    $(eval $(call monhub-goal,$(PREV_PATH)))
    $(eval $(call monhub-build-goal,$(PREV_PATH)))
    $(eval $(call monhub-test-goal,$(PREV_PATH)))
    $(eval $(call monhub-clean-goal,$(PREV_PATH)))
    ifneq ($(wildcard $(PREV_PATH)/package.json),)
      $(eval $(call monhub-release-goal,$(PREV_PATH)))
    endif
  endif
endif

# if there's a Dockerfile, create the appropriate rules for it unless disabled
ifneq ($($(ABS_PREV_MAKEFILE)_DOCKER_TARGET),false)
  ifneq ($(wildcard $(PREV_PATH)/Dockerfile),)
    $(eval $(call build-docker-goal,$(PREV_PATH)))
    $(eval $(call push-docker-goal,$(PREV_PATH)))
  endif
endif

# include rules for directory level "-all" targets for recursing
ifneq ($($(ABS_PREV_MAKEFILE)_RECURSE_SUBMAKEFILES),false)
  $(eval $(call subdir-recurse-goal,$(PREV_PATH)))
endif

# include rules for directory level "-all" targets
$(eval $(call subdir-goal,$(PREV_PATH)))

# include makefiles from 1 level down in directory tree if they exist (and by recursion every makefile in the tree that is referenced) unless disabled
ifneq ($($(ABS_PREV_MAKEFILE)_RECURSE_SUBMAKEFILES),false)
  $(eval $(call make-goal,$(PREV_PATH)))
endif

include $(wallaroo_dir)/Makefile
