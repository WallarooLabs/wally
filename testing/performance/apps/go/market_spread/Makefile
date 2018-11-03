# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1


# The following are control variables that determine what logic from `rules.mk` is enabled

# `true`/`false` to enable/disable the actual unit test command so it can be overridden (the targets are still created)
# applies to both the pony and elixir test targets
$(abspath $(lastword $(MAKEFILE_LIST)))_UNIT_TEST_COMMAND := false

# `true`/`false` to enable/disable generate pony related targets (build/test/clean) for pony sources in this directory
# otherwise targets only get created if there are pony sources (*.pony) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := false

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := false

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := false

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := false

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := false

MARKET_SPREAD_GO_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
GO_PONY_LIB := $(wallaroo_path)/go_api/go
MARKET_SPREAD_GOPATH := $(MARKET_SPREAD_GO_PATH)/go:$(GO_PONY_LIB)

# standard rules generation makefile
include $(rules_mk_path)

build-testing-performance-apps-go-market_spread: market_spread_go_build
clean-testing-performance-apps-go-market_spread: market_spread_go_clean

market_spread_go_build: $(MARKET_SPREAD_GO_PATH)/market_spread

market_spread_go_clean:
	$(QUIET)rm -rf $(MARKET_SPREAD_GO_PATH)/lib $(MARKET_SPREAD_GO_PATH)/.deps $(MARKET_SPREAD_GO_PATH)/market_spread $(MARKET_SPREAD_GO_PATH)/market_spread.d $(MARKET_SPREAD_GO_PATH)/market_spread.dSYM

-include $(MARKET_SPREAD_GO_PATH)/market_spread.d
$(MARKET_SPREAD_GO_PATH)/market_spread: $(MARKET_SPREAD_GO_PATH)/lib/libwallaroo.a
	$(call PONYC,$(abspath $(MARKET_SPREAD_GO_PATH:%/=%)))

$(MARKET_SPREAD_GO_PATH)/lib/libwallaroo.a: $(MARKET_SPREAD_GO_PATH)/go/src/market_spread/*.go $(MARKET_SPREAD_GO_PATH)/go/src/market_spread/*/*.go
	$(QUIET)export GOPATH=$(MARKET_SPREAD_GOPATH) && go build -buildmode=c-archive -o $(MARKET_SPREAD_GO_PATH)lib/libwallaroo.a market_spread

# end of prevent rules from being evaluated/included multiple times
endif
