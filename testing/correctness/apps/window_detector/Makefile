# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../../../../Makefile
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


WINDOW_DETECTOR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
window_detector_tests: LOGLEVEL = debug

# standard rules generation makefile
include $(rules_mk_path)


build-testing-correctness-apps-window_detector: build-machida
build-testing-correctness-apps-window_detector: build-machida3
integration-tests-testing-correctness-apps-window_detector: build-testing-correctness-apps-window_detector
integration-tests-testing-correctness-apps-window_detector: window_detector_tests


# single name space for testing
window_detector_tests: window_detector_tests_python
# TODO: uncomment this!
#window_detector_tests: window_detector_tests_python3

# group the tests by target API (Pony, Python, Python3)
# Pony

# Python
# TODO: uncomment these:
window_detector_tests_python: window_detector_tumbling_test_python
window_detector_tests_python: window_detector_counting_test_python
#window_detector_tests_python: window_detector_sliding_test_python
#window_detector_tests_python: window_detector_tumbling_gensource_test_python
#window_detector_tests_python: window_detector_counting_gensource_test_python
#window_detector_tests_python: window_detector_sliding_gensource_test_python
window_detector_tests_python: window_detector_tumbling_alo_source_test_python
# TODO: uncomment these
#window_detector_tests_python: window_detector_counting_alo_source_test_python
#window_detector_tests_python: window_detector_sliding_alo_source_test_python


# Python3
#window_detector_tests_python3: window_detector_tumbling_test_python3
#window_detector_tests_python3: window_detector_sliding_test_python3
#window_detector_tests_python3: window_detector_counting_test_python3
#window_detector_tests_python3: window_detector_tumbling_gensource_test_python3
#window_detector_tests_python3: window_detector_counting_gensource_test_python3
#window_detector_tests_python3: window_detector_sliding_gensource_test_python3
#window_detector_tests_python3: window_detector_tumbling_alo_source_test_python3
#window_detector_tests_python3: window_detector_sliding_alo_source_test_python3
#window_detector_tests_python3: window_detector_counting_alo_source_test_python3

# Individual test definitions below
#
# Python tests
window_detector_tumbling_alo_source_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 100 \
		--alo-sequence-sender key_1 100 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --source alo --window-type tumbling $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_sliding_alo_source_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 100 \
		--alo-sequence-sender key_1 100 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --source alo --window-type sliding $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_counting_alo_source_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 100 \
		--alo-sequence-sender key_1 100 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --source alo --window-type counting $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_tumbling_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' 0 '>I' key_0 \
		--sequence-sender '(0,100]' 0 '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --window-type tumbling $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_counting_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' 0 '>I' key_0 \
		--sequence-sender '(0,100]' 0 '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --window-type counting $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type counting --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_sliding_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' 0 '>I' key_0 \
		--sequence-sender '(0,100]' 0 '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --window-type sliding $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type sliding --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 400

window_detector_tumbling_gensource_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sources 0 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --gen-source --window-type tumbling $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200 \
		--sink-expect-allow-more

window_detector_counting_gensource_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sources 0 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --gen-source --window-type counting $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type counting --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200 \
		--sink-expect-allow-more

window_detector_sliding_gensource_test_python:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sources 0 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module window_detector --gen-source --window-type sliding $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type sliding --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 400 \
		--sink-expect-allow-more

# Python3 tests
window_detector_tumbling_alo_source_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 100 \
		--alo-sequence-sender key_1 100 \
		--log-level $(LOGLEVEL) \
		--command 'machida2 --application-module window_detector --source alo --window-type tumbling $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_sliding_alo_source_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 100 \
		--alo-sequence-sender key_1 100 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --source alo --window-type sliding $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_counting_alo_source_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 100 \
		--alo-sequence-sender key_1 100 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --source alo --window-type counting $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_tumbling_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' 0 '>I' key_0 \
		--sequence-sender '(0,100]' 0 '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --window-type tumbling $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_counting_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' 0 '>I' key_0 \
		--sequence-sender '(0,100]' 0 '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --window-type counting $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --window-type counting --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200

window_detector_sliding_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' 0 '>I' key_0 \
		--sequence-sender '(0,100]' 0 '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --window-type sliding $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --window-type sliding --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 400

window_detector_tumbling_gensource_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sources 0 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --gen-source --window-type tumbling $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --window-type tumbling --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200 \
		--sink-expect-allow-more

window_detector_counting_gensource_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sources 0 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --gen-source --window-type counting $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --window-type counting --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 200 \
		--sink-expect-allow-more

window_detector_sliding_gensource_test_python3:
	cd $(WINDOW_DETECTOR_PATH) && \
	integration_test \
		--sources 0 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module window_detector --gen-source --window-type sliding $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python3 _validate.py --window-type sliding --output' \
		--output 'received.txt' \
		--batch-size 50 \
		--workers 5 \
		--sink-expect 400 \
		--sink-expect-allow-more

# end of prevent rules from being evaluated/included multiple times
endif
