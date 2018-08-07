.PHONY: generate-canonical-results test \
	start-leader start-worker send-input send-eom \
	remove-resilience-files

N_WORKERS := 4
N_MESSAGES := 1
SOURCE_PORT := 8888
SINK_PORT := 9999
SENDER := giles_sender
RECEIVER := data_receiver

run-job: kill-machida clear-logs
	$(MAKE) -s start-listener &\
	sleep 1; \
	$(MAKE) -s start-cluster N_WORKERS=$(N_WORKERS) &\
	$(MAKE) -s wait-for-workers WAIT_FOR=$(N_WORKERS) && \
	$(MAKE) -s send-input

remove-resilience-files:
	@rm -rf /tmp/parallel*

start-leader: remove-resilience-files
	exec machida --application-module parallel_test \
	  --in 0.0.0.0:$(SOURCE_PORT) \
	  --out 127.0.0.1:$(SINK_PORT) \
          --metrics 127.0.0.1:5001 \
          --control 127.0.0.1:12500 \
          --data 127.0.0.1:12501 \
          --external 127.0.0.1:5050 \
          --cluster-initializer --ponythreads=1 \
	  --worker-count $(N_WORKERS) \
          --ponynoblock --ponynopin

start-worker:
	exec machida --application-module parallel_test \
	  --in 0.0.0.0:1$$(($(SOURCE_PORT)+$(N))) \
	  --out 127.0.0.1:$(SINK_PORT) \
          --metrics 127.0.0.1:5001 \
          --control 127.0.0.1:12500 \
          --name worker$(N) --ponythreads=1 \
          --ponynoblock --ponynopin

start-cluster:
	@$(MAKE) -s start-leader N_WORKERS=$(N_WORKERS) >worker0.log 2>&1 & \
	sleep 3 ;\
	  for i in `seq $$(($(N_WORKERS)-1))`; do\
	      $(MAKE) -s start-worker N=$$i >worker$$i.log 2>&1 &\
	  done

wait-for-workers:
	@echo "*WAITING FOR $(WAIT_FOR) WORKERS"; \
	while [ `grep -c 'Application is ready to work' worker*.log \
		| awk -F: '{i+=$$2} END {print i}'` != "$(WAIT_FOR)" ]; \
        do echo -n '.'; sleep 1; done


kill-machida:
	-killall -9 machida

clear-logs:
	rm -rf worker*log

send-input:
	$(SENDER) --host 127.0.0.1:$(SOURCE_PORT) \
	--messages $(N_MESSAGES)

start-listener:
	-killall -9 $(RECEIVER)
	$(RECEIVER) --listen 127.0.0.1:$(SINK_PORT) > results.log
