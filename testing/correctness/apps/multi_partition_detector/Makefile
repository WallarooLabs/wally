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


MULTI_PARTITION_DETECTOR_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))
multi_partition_detector_tests: LOGLEVEL = error

# standard rules generation makefile
include $(rules_mk_path)


build-testing-correctness-apps-multi_partition_detector: build-machida
build-testing-correctness-apps-multi_partition_detector: build-machida3
integration-tests-testing-correctness-apps-multi_partition_detector: build-testing-correctness-apps-multi_partition_detector
integration-tests-testing-correctness-apps-multi_partition_detector: multi_partition_detector_tests

# Group the tests under a single target
multi_partition_detector_tests: multi_partition_detector_tests_pony
multi_partition_detector_tests: multi_partition_detector_tests_python
multi_partition_detector_tests: multi_partition_detector_tests_python3

# group the tests by target API (Pony, Python, Python3)
# Pony
multi_partition_detector_tests_pony: multi_partition_alo_source_test_pony
multi_partition_detector_tests_pony: multi_partition_alo_source_test_pony_10_worker
multi_partition_detector_tests_pony: multi_partition_detector_test_pony
multi_partition_detector_tests_pony: multi_partition_detector_test_pony_gen_source
multi_partition_detector_tests_pony: multi_partition_alo_source_test_pony_10_worker
multi_partition_detector_tests_pony: multi_partition_detector_test_pony_10_worker
multi_partition_detector_tests_pony: multi_partition_detector_test_pony_gen_source_10_worker

# Python
multi_partition_detector_tests_python: multi_partition_detector_test_python_alo
multi_partition_detector_tests_python: multi_partition_detector_test_python_alo_10_worker
multi_partition_detector_tests_python: multi_partition_detector_test_python
multi_partition_detector_tests_python: multi_partition_detector_test_python_10_worker
multi_partition_detector_tests_python: multi_partition_detector_test_python_gen_source
multi_partition_detector_tests_python: multi_partition_detector_test_python_gen_source_10_worker

# Python3
multi_partition_detector_tests_python3: multi_partition_detector_test_python3_alo
multi_partition_detector_tests_python3: multi_partition_detector_test_python3_alo_10_worker
multi_partition_detector_tests_python3: multi_partition_detector_test_python3
multi_partition_detector_tests_python3: multi_partition_detector_test_python3_gen_source
multi_partition_detector_tests_python3: multi_partition_detector_test_python3_10_worker
multi_partition_detector_tests_python3: multi_partition_detector_test_python3_gen_source_10_worker


# Individual test definitions below
#
# Python tests
multi_partition_detector_test_python_alo:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 '(0,100]' Detector \
		--alo-sequence-sender key_1 '(0,100]' Detector \
		--alo-sequence-sender key_0 '(100,200]' Detector \
		--alo-sequence-sender key_1 '(100,200]' Detector \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module multi_partition_detector --source alo $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200]

multi_partition_detector_test_python_alo_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 '(0,100]' Detector \
		--alo-sequence-sender key_1 '(0,100]' Detector \
		--alo-sequence-sender key_2 '(0,100]' Detector \
		--alo-sequence-sender key_3 '(0,100]' Detector \
		--alo-sequence-sender key_4 '(0,100]' Detector \
		--alo-sequence-sender key_5 '(0,100]' Detector \
		--alo-sequence-sender key_6 '(0,100]' Detector \
		--alo-sequence-sender key_7 '(0,100]' Detector \
		--alo-sequence-sender key_8 '(0,100]' Detector \
		--alo-sequence-sender key_9 '(0,100]' Detector \
		--alo-sequence-sender key_0 '(100,200]' Detector \
		--alo-sequence-sender key_1 '(100,200]' Detector \
		--alo-sequence-sender key_2 '(100,200]' Detector \
		--alo-sequence-sender key_3 '(100,200]' Detector \
		--alo-sequence-sender key_4 '(100,200]' Detector \
		--alo-sequence-sender key_5 '(100,200]' Detector \
		--alo-sequence-sender key_6 '(100,200]' Detector \
		--alo-sequence-sender key_7 '(100,200]' Detector \
		--alo-sequence-sender key_8 '(100,200]' Detector \
		--alo-sequence-sender key_9 '(100,200]' Detector \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module multi_partition_detector --source alo $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200] \
		--sink-await-key key_2 [197,198,199,200] \
		--sink-await-key key_3 [197,198,199,200] \
		--sink-await-key key_4 [197,198,199,200] \
		--sink-await-key key_5 [197,198,199,200] \
		--sink-await-key key_6 [197,198,199,200] \
		--sink-await-key key_7 [197,198,199,200] \
		--sink-await-key key_8 [197,198,199,200] \
		--sink-await-key key_9 [197,198,199,200]

multi_partition_detector_test_python:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' Detector '>I' key_0 \
		--sequence-sender '(0,100]' Detector '>I' key_1 \
		--sequence-sender '(100,200]' Detector '>I' key_0 \
		--sequence-sender '(100,200]' Detector '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module multi_partition_detector $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200]

multi_partition_detector_test_python_gen_source:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module multi_partition_detector --source gensource $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-expect 200 \
		--sink-expect-allow-more

multi_partition_detector_test_python_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,1000]' Detector '>I' key_0 \
		--sequence-sender '(0,1000]' Detector '>I' key_1 \
		--sequence-sender '(0,1000]' Detector '>I' key_2 \
		--sequence-sender '(0,1000]' Detector '>I' key_3 \
		--sequence-sender '(0,1000]' Detector '>I' key_4 \
		--sequence-sender '(0,1000]' Detector '>I' key_5 \
		--sequence-sender '(0,1000]' Detector '>I' key_6 \
		--sequence-sender '(0,1000]' Detector '>I' key_7 \
		--sequence-sender '(0,1000]' Detector '>I' key_8 \
		--sequence-sender '(0,1000]' Detector '>I' key_9 \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module multi_partition_detector $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-expect 10000

multi_partition_detector_test_python_gen_source_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--log-level $(LOGLEVEL) \
		--command 'machida --application-module multi_partition_detector --source gensource $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-expect 10000 \
		--sink-expect-allow-more

# Python3 tests
multi_partition_detector_test_python3_alo:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 '(0,100]' Detector \
		--alo-sequence-sender key_1 '(0,100]' Detector \
		--alo-sequence-sender key_0 '(100,200]' Detector \
		--alo-sequence-sender key_1 '(100,200]' Detector \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module multi_partition_detector --source alo $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200]

multi_partition_detector_test_python3_alo_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 '(0,100]' Detector \
		--alo-sequence-sender key_1 '(0,100]' Detector \
		--alo-sequence-sender key_2 '(0,100]' Detector \
		--alo-sequence-sender key_3 '(0,100]' Detector \
		--alo-sequence-sender key_4 '(0,100]' Detector \
		--alo-sequence-sender key_5 '(0,100]' Detector \
		--alo-sequence-sender key_6 '(0,100]' Detector \
		--alo-sequence-sender key_7 '(0,100]' Detector \
		--alo-sequence-sender key_8 '(0,100]' Detector \
		--alo-sequence-sender key_9 '(0,100]' Detector \
		--alo-sequence-sender key_0 '(100,200]' Detector \
		--alo-sequence-sender key_1 '(100,200]' Detector \
		--alo-sequence-sender key_2 '(100,200]' Detector \
		--alo-sequence-sender key_3 '(100,200]' Detector \
		--alo-sequence-sender key_4 '(100,200]' Detector \
		--alo-sequence-sender key_5 '(100,200]' Detector \
		--alo-sequence-sender key_6 '(100,200]' Detector \
		--alo-sequence-sender key_7 '(100,200]' Detector \
		--alo-sequence-sender key_8 '(100,200]' Detector \
		--alo-sequence-sender key_9 '(100,200]' Detector \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module multi_partition_detector --source alo $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200] \
		--sink-await-key key_2 [197,198,199,200] \
		--sink-await-key key_3 [197,198,199,200] \
		--sink-await-key key_4 [197,198,199,200] \
		--sink-await-key key_5 [197,198,199,200] \
		--sink-await-key key_6 [197,198,199,200] \
		--sink-await-key key_7 [197,198,199,200] \
		--sink-await-key key_8 [197,198,199,200] \
		--sink-await-key key_9 [197,198,199,200]

multi_partition_detector_test_python3:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' Detector '>I' key_0 \
		--sequence-sender '(0,100]' Detector '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module multi_partition_detector $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-expect 200

multi_partition_detector_test_python3_gen_source:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module multi_partition_detector --source gensource $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-expect 200 \
		--sink-expect-allow-more

multi_partition_detector_test_python3_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,1000]' Detector '>I' key_0 \
		--sequence-sender '(0,1000]' Detector '>I' key_1 \
		--sequence-sender '(0,1000]' Detector '>I' key_2 \
		--sequence-sender '(0,1000]' Detector '>I' key_3 \
		--sequence-sender '(0,1000]' Detector '>I' key_4 \
		--sequence-sender '(0,1000]' Detector '>I' key_5 \
		--sequence-sender '(0,1000]' Detector '>I' key_6 \
		--sequence-sender '(0,1000]' Detector '>I' key_7 \
		--sequence-sender '(0,1000]' Detector '>I' key_8 \
		--sequence-sender '(0,1000]' Detector '>I' key_9 \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module multi_partition_detector $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-expect 10000

multi_partition_detector_test_python3_gen_source_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--log-level $(LOGLEVEL) \
		--command 'machida3 --application-module multi_partition_detector --source gensource $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-expect 10000 \
		--sink-expect-allow-more

# Pony tests
multi_partition_alo_source_test_pony:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 '(0,100]' Detector \
		--alo-sequence-sender key_1 '(0,100]' Detector \
		--alo-sequence-sender key_0 '(100,200]' Detector \
		--alo-sequence-sender key_1 '(100,200]' Detector \
		--log-level $(LOGLEVEL) \
		--command './multi_partition_detector --source alo $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200]

multi_partition_detector_test_pony:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,100]' Detector '>I' key_0 \
		--sequence-sender '(0,100]' Detector '>I' key_1 \
		--log-level $(LOGLEVEL) \
		--command './multi_partition_detector $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-await-key key_0 [97,98,99,100] \
		--sink-await-key key_1 [97,98,99,100]

multi_partition_detector_test_pony_gen_source:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--log-level $(LOGLEVEL) \
		--command './multi_partition_detector --source gensource $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 2 \
		--sink-expect 200 \
		--sink-expect-allow-more

multi_partition_alo_source_test_pony_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--alo-sequence-sender key_0 '(0,100]' Detector \
		--alo-sequence-sender key_1 '(0,100]' Detector \
		--alo-sequence-sender key_2 '(0,100]' Detector \
		--alo-sequence-sender key_3 '(0,100]' Detector \
		--alo-sequence-sender key_4 '(0,100]' Detector \
		--alo-sequence-sender key_5 '(0,100]' Detector \
		--alo-sequence-sender key_6 '(0,100]' Detector \
		--alo-sequence-sender key_7 '(0,100]' Detector \
		--alo-sequence-sender key_8 '(0,100]' Detector \
		--alo-sequence-sender key_9 '(0,100]' Detector \
		--alo-sequence-sender key_0 '(100,200]' Detector \
		--alo-sequence-sender key_1 '(100,200]' Detector \
		--alo-sequence-sender key_2 '(100,200]' Detector \
		--alo-sequence-sender key_3 '(100,200]' Detector \
		--alo-sequence-sender key_4 '(100,200]' Detector \
		--alo-sequence-sender key_5 '(100,200]' Detector \
		--alo-sequence-sender key_6 '(100,200]' Detector \
		--alo-sequence-sender key_7 '(100,200]' Detector \
		--alo-sequence-sender key_8 '(100,200]' Detector \
		--alo-sequence-sender key_9 '(100,200]' Detector \
		--log-level $(LOGLEVEL) \
		--command './multi_partition_detector --source alo $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-await-key key_0 [197,198,199,200] \
		--sink-await-key key_1 [197,198,199,200] \
		--sink-await-key key_2 [197,198,199,200] \
		--sink-await-key key_3 [197,198,199,200] \
		--sink-await-key key_4 [197,198,199,200] \
		--sink-await-key key_5 [197,198,199,200] \
		--sink-await-key key_6 [197,198,199,200] \
		--sink-await-key key_7 [197,198,199,200] \
		--sink-await-key key_8 [197,198,199,200] \
		--sink-await-key key_9 [197,198,199,200]

multi_partition_detector_test_pony_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--sequence-sender '(0,1000]' Detector '>I' key_0 \
		--sequence-sender '(0,1000]' Detector '>I' key_1 \
		--sequence-sender '(0,1000]' Detector '>I' key_2 \
		--sequence-sender '(0,1000]' Detector '>I' key_3 \
		--sequence-sender '(0,1000]' Detector '>I' key_4 \
		--sequence-sender '(0,1000]' Detector '>I' key_5 \
		--sequence-sender '(0,1000]' Detector '>I' key_6 \
		--sequence-sender '(0,1000]' Detector '>I' key_7 \
		--sequence-sender '(0,1000]' Detector '>I' key_8 \
		--sequence-sender '(0,1000]' Detector '>I' key_9 \
		--log-level $(LOGLEVEL) \
		--command './multi_partition_detector $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-expect 10000

multi_partition_detector_test_pony_gen_source_10_worker:
	cd $(MULTI_PARTITION_DETECTOR_PATH) && \
	integration_test \
		--log-level $(LOGLEVEL) \
		--command './multi_partition_detector --source gensource $(RUN_WITH_RESILIENCE)' \
		--validation-cmd 'python _validate.py --output' \
		--output 'received.txt' \
		--batch-size 10 \
		--workers 10 \
		--sink-expect 10000 \
		--sink-expect-allow-more

# end of prevent rules from being evaluated/included multiple times
endif
