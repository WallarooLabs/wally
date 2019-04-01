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

MARKET_SPREAD_PONY_PATH := $(dir $(abspath $(lastword $(MAKEFILE_LIST))))


# standard rules generation makefile
include $(rules_mk_path)

integration-tests-testing-performance-apps-market-spread: market-spread_pony_test

market-spread_pony_test:
	cd $(MARKET_SPREAD_PONY_PATH) && \
	python _test/gen.py && \
	integration_test --framed-file-sender _market.txt 1 \
	  --framed-file-sender _orders.txt 0 \
	  --log-level error \
	  --command './market-spread $(RUN_WITH_RESILIENCE)' \
	  --validation-cmd 'python _test/validate.py --expected $(MARKET_SPREAD_PONY_PATH)/_expected.txt --output' \
	  --output 'received.txt' \
	  --sources 2 \
	  --sink-expect 1000

# Kafka-on-demand Lifted from
# https://github.com/WallarooLabs/streaming-avro-over-kafka

.PHONY: test \
	check-for-wallaroo \
	start-kafka stop-kafka setup-topics reset\
	start-app \
	start-generator \
	tail-output \

K_BIN = ./kafka/bin/
IN_TOPIC = sensor-readings
OUT_TOPIC = sensor-aggregates
K_VERSION := 2.12-2.2.0

start-app: check-for-wallaroo
	-rm /tmp/app-initializer.*
	machida --application-module app \
	  --kafka_source_topic $(IN_TOPIC) \
	  --kafka_source_brokers 127.0.0.1:9092 \
	  --kafka_sink_topic $(OUT_TOPIC) \
	  --kafka_sink_brokers 127.0.0.1:9092 \
	  --kafka_sink_max_message_size 100000 \
	  --kafka_sink_max_produce_buffer_ms 100 \
	  --metrics 127.0.0.1:5001 \
	  --control 127.0.0.1:12500 \
	  --data 127.0.0.1:12501 \
	  --external 127.0.0.1:5050 \
	  --cluster-initializer --ponythreads=1 \
	  --ponynoblock

start-generator:
	./generator.py

tail-output:
	$(K_BIN)/kafka-console-consumer.sh \
	  --bootstrap-server localhost:9092 \
	  --topic $(OUT_TOPIC)

$(K_BIN): kafka log

log:
	mkdir -p log

kafka: tmp/kafka_$(K_VERSION).tgz
	(cd tmp && tar xzf $(notdir $<))
	ln -s $(basename $<) $@

tmp/kafka_$(K_VERSION).tgz:
	mkdir -p tmp
	(cd tmp &&\
         curl -sO 'https://www-us.apache.org/dist/kafka/2.2.0/kafka_$(K_VERSION).tgz')

start-kafka: $(K_BIN)
	$(K_BIN)/zookeeper-server-start.sh \
	  ./kafka/config/zookeeper.properties > ./log/zk.log 2>&1 &
	while !(nc -z localhost 2181); do printf . ; sleep 1 ; done
	$(K_BIN)/kafka-server-start.sh \
	  ./kafka/config/server.properties > ./log/kafka.log 2>&1 &
	while !(nc -z localhost 9092); do printf . ; sleep 1 ; done

stop-kafka: $(K_BIN)
	$(K_BIN)/zookeeper-server-stop.sh
	$(K_BIN)/kafka-server-stop.sh

reset:
	-ps aux | grep [k]afka | awk '{print $$2}' | xargs -L1 kill -9
	-ps aux | grep [z]ook | awk '{print $$2}' | xargs -L1 kill -9
	sleep 1
	rm -rf ./kafka/logs/*
	rm -rf /tmp/kafka-logs
	rm -rf /tmp/zookeeper

setup-topics: $(K_BIN)
	-$(K_BIN)/kafka-topics.sh --create --zookeeper localhost:2181 \
	  --partitions 1 --replication-factor 1\
	  --config delete.retention.ms=1 \
	  --topic $(IN_TOPIC)
	-$(K_BIN)/kafka-topics.sh --create --zookeeper localhost:2181 \
	  --config delete.retention.ms=1 \
	  --partitions 1 --replication-factor 1\
	  --topic $(OUT_TOPIC)

# end of prevent rules from being evaluated/included multiple times
endif
