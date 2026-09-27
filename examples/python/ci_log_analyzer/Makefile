# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

$(abspath $(lastword $(MAKEFILE_LIST)))_UNIT_TEST_COMMAND := false
$(abspath $(lastword $(MAKEFILE_LIST)))_PONY_TARGET := false
$(abspath $(lastword $(MAKEFILE_LIST)))_PONYC_TARGET := false
$(abspath $(lastword $(MAKEFILE_LIST)))_EXS_TARGET := false
$(abspath $(lastword $(MAKEFILE_LIST)))_DOCKER_TARGET := false
$(abspath $(lastword $(MAKEFILE_LIST)))_RECURSE_SUBMAKEFILES := false

CI_LOG_ANALYZER_PY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))

# standard rules generation makefile
include $(rules_mk_path)

build-examples-python-ci_log_analyzer: build-machida
build-examples-python-ci_log_analyzer: build-machida3
integration-tests-examples-python-ci_log_analyzer: build-examples-python-ci_log_analyzer

integration-tests-examples-python-ci_log_analyzer: ci_log_analyzer_py_test
integration-tests-examples-python-ci_log_analyzer: ci_log_analyzer_py3_test

ci_log_analyzer_py_test:
	cd $(CI_LOG_ANALYZER_PY_PATH) && \
	integration_test \
		--log-level error \
		--command 'machida --application-module ci_log_analyzer $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output received.txt \
		--sink-mode newlines \
		--sink-expect 3 \
		--sink-expect-allow-more \
		--workers 2

ci_log_analyzer_py3_test:
	cd $(CI_LOG_ANALYZER_PY_PATH) && \
	integration_test \
		--log-level error \
		--command 'machida3 --application-module ci_log_analyzer $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --output' \
		--output received.txt \
		--sink-mode newlines \
		--sink-expect 3 \
		--sink-expect-allow-more \
		--workers 2
endif
