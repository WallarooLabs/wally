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
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := false

# `true`/`false` to enable/disable generate docker related targets (build/push) for a Dockerfile in this directory
# otherwise targets only get created if there is a Dockerfile in this directory
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := false

# `true`/`false` to enable/disable recursing into Makefiles of subdirectories if they exist
# (and by recursion every makefile in the tree that is referenced)
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := false


ALERTS_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

# integration-tests-examples-pony-alerts_windowed: alerts_windowed_pony_test

# integration-tests-examples-pony-alerts-windowed: alerts_windowed_test

# alphabet_pony_test:
# 	cd $(ALPHABET_PONY_PATH) && \
# 	python _test/gen.py && \
# 	integration_test --framed-file-sender _test.txt \
# 		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
# 		--log-level error \
# 		--batch-size 10 \
# 		--output 'received.txt' \
# 		--command './alphabet $(RUN_WITH_RESILIENCE)' \
# 		--workers 4 \
# 		--sink-expect 1000

# alerts_windowed_test:
# 	cd $(ALERTS_PATH) && \
# 	integration_test --framed-file-sender \
# 	  _test.txt --validation-cmp \
# 	  --expected-file _expected.txt \
# 		--log-level error \
# 		--command 'alerts $(RUN_WITH_RESILIENCE)'
#		--sink-mode newlines

endif
