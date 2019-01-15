# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../Makefile
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
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := true

# `true`/`false` to enable/disable generate final file build target using ponyc command for the pony build target so
# it can be overridden manually
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := true

# `true`/`false` to enable/disable generate exs related targets (build/test/clean) for elixir sources in this directory
# otherwise targets only get created if there are elixir sources (*.exs) in this directory.
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := true

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := true

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := true


WINDOW_CHAIN_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

integration-tests-examples-pony-alphabet: window_chain-test

start:
	rm -rf /tmp/Alerts*
	-pkill -f data_receiver
	-pkill -f data_receiver
	-pkill -f window_chain
	-pkill -f window_chain
	cd $(WINDOW_CHAIN_PATH) && \
	data_receiver --listen 127.0.0.1:9999 > out.log & \
	./window_chain \
	  --in 127.0.0.1:8888 \
	  --out 127.0.0.1:9999 \
          --metrics 127.0.0.1:5001 \
          --control 127.0.0.1:12500 \
          --data 127.0.0.1:12501 \
          --external 127.0.0.1:5050 \
          --cluster-initializer --ponythreads=4 \
          --ponynoblock --ponynopin > app.log &



# end of prevent rules from being evaluated/included multiple times
endif
