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
PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
RECURSE_SUBMAKEFILES := false

WORD_COUNT_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-demos-python_word_count: build-machida
test-demos-python_word_count: build-demos-python_word_count
test-demos-python_word_count: word_count_py_test
clean-demos-python_word_count: word_count_py_clean

word_count_py_test:
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test --newline-file-sender count_this.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida --application-module word_count' \
		--sink-mode newlines \
		--sink-expect 482
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test --newline-file-sender count_this.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida --application-module word_count' \
		--sink-mode newlines \
		--sink-expect 482 \
		--workers 2
	cd $(WORD_COUNT_PY_PATH) && \
	integration_test --newline-file-sender count_this.txt \
		--validation-cmd 'python _test/validate.py --expected _expected.json --output' \
		--log-level error \
		--batch-size 1 \
		--output 'received.txt' \
		--command 'machida --application-module word_count' \
		--sink-mode newlines \
		--sink-expect 482 \
		--workers 3

word_count_py_clean:
	$(QUIET)rm -f $(WORD_COUNT_PY_PATH)/received.txt

# args to RUN_DAGON and RUN_DAGON_SPIKE: $1 = test name; $2 = ini file; $3 = timeout; $4 = wesley test command, $5 = include in CI
# NOTE: all paths must be relative to buffy directory (use buffy_path variable)

##<NAME OF TARGET>: #used as part of `make help` command ## <DESCRIPTION OF TARGET>
#$(eval $(call RUN_DAGON\
#,<NAME OF TARGET> \
#,$(buffy_path)/<PATH TO INI FILE> \
#,<TIMEOUT VALUE> \
#,<WESLEY TEST COMMAND> \
#,<INCLUDE IN CI>))
endif
