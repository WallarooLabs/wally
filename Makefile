current_dir := $(shell pwd)
latest_ponyc_tag := $(shell curl -s \
  https://hub.docker.com/r/sendence/ponyc/tags/ | grep -o \
  'sendence-[0-9.-]*-' | sed 's/sendence-\([0-9.-]*\)-/\1/' \
  | sort -un | tail -n 1)# latest ponyc tag
docker_image_version ?= $(shell git describe --tags --always)## Docker Image Tag to use
docker_image_repo_host ?= docker.sendence.com:5043## Docker Repository to use
docker_image_repo ?= $(docker_image_repo_host)/sendence## Docker Repository to use
arch ?= native## Architecture to build for
in_docker ?= false## Whether already in docker or not (used by CI)
ponyc_tag ?= sendence-$(latest_ponyc_tag)-debug## tag for ponyc docker to use
ponyc_runner ?= sendence/ponyc## ponyc docker image to use
debug ?= false## Use ponyc debug option (-d)
debug_arg :=# Final argument string for docker no pull
docker_host ?= $(DOCKER_HOST)## docker host to build/run containers on
ifeq ($(docker_host),)
  docker_host := unix:///var/run/docker.sock
endif
docker_host_arg := --host=$(docker_host)# docker host argument
dagon_docker_host ?= ## Dagon docker host arg (defaults to docker_host value)
monhub_builder ?= monitoring-hub-builder
monhub_builder_tag ?= latest

ifeq ($(dagon_docker_host),)
  dagon_docker_host := $(docker_host)
endif

dagon_docker_host_arg := --host=$(dagon_docker_host)# dagon docker host argument

ifeq ($(shell uname -s),Linux)
  extra_xargs_arg := -r
  docker_user_arg := -u `id -u`
  extra_awk_arg := \\
endif

ifeq ($(debug),true)
  debug_arg := -d
endif

ifdef arch
  ifeq (,$(filter $(arch),amd64 armhf native))
    $(error Unknown architecture "$(arch)")
  endif
endif

ifdef in_docker
  ifeq (,$(filter $(in_docker),false true))
    $(error Unknown in_docker option "$(use_docker)")
  endif
endif

ifeq ($(arch),armhf)
  ponyc_arch_args := --triple arm-unknown-linux-gnueabihf --cpu=armv7-a
endif

ifneq ($(arch),native)
  quote = '
  ponyc_docker_args = docker run --rm -it $(docker_user_arg) -v \
        $(current_dir):$(current_dir) \
        -v $(HOME)/.gitconfig:/.gitconfig \
        -v $(HOME)/.gitconfig:/root/.gitconfig \
        -w $(current_dir)/$(1) --entrypoint bash \
        $(ponyc_runner):$(ponyc_tag) -c $(quote)

  monhub_docker_args = docker run --rm -it -v \
        $(current_dir):$(current_dir) \
        -v $(HOME)/.gitconfig:/.gitconfig \
        -v $(HOME)/.gitconfig:/root/.gitconfig \
        -v $(HOME)/.git-credential-cache:/root/.git-credential-cache \
        -v $(HOME)/.git-credential-cache:/.git-credential-cache \
        -w $(current_dir)/$(1) --entrypoint bash \
        $(docker_image_repo_host)/$(monhub_builder):$(monhub_builder_tag) -c $(quote)
endif


define PONYC
  cd $(current_dir)/$(1) && $(ponyc_docker_args) stable fetch \
    $(if $(filter $(ponyc_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(ponyc_docker_args) stable env ponyc $(ponyc_arch_args) \
    $(debug_arg) . $(if $(filter $(ponyc_docker_args),docker),$(quote))
endef

define MONHUBC
  cd $(current_dir)/$(1) && $(monhub_docker_args) MIX_ENV=prod mix deps.clean --all \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) MIX_ENV=prod mix deps.get --only prod \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) MIX_ENV=prod mix compile \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) npm install \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) npm run build:production \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) MIX_ENV=prod mix phoenix.digest \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) MIX_ENV=prod mix release.clean \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
  cd $(current_dir)/$(1) && $(monhub_docker_args) MIX_ENV=prod mix release \
    $(if $(filter $(monhub_docker_args),docker),$(quote))
endef


default: build

print-%  : ; @echo $* = $($*)

docker-arch-check:
	$(if $(filter $(arch),native),$(error Arch cannot be 'native' \
          for docker build!),)

monhub-arch-check:
	$(if $(filter $(arch),armhf),$(error Arch cannot be 'armhf' \
          for building of monitoring hub!),)

build-buffy-components: build-receiver build-sender build-dagon build-dagon-child build-fallor

build-apps: build-wesley build-double-divide build-avg-of-avgs build-state-avg-of-avgs build-quadruple build-market-spread build-word-count build-word-length-count ## Build Pony based programs for Buffy

build: build-buffy-components build-apps build-wesley

build-receiver: ## Build giles receiver
	$(call PONYC,giles/receiver)

build-sender: ## Build giles sender
	$(call PONYC,giles/sender)

build-double-divide: ## build double/divide app
	$(call PONYC,apps/double-divide)

build-avg-of-avgs: ## build average of averages app
	$(call PONYC,apps/avg-of-avgs)

build-state-avg-of-avgs: ## build shared state average of averages app
	$(call PONYC,apps/state-avg-of-avgs)

build-quadruple: ## build quadruple app
	$(call PONYC,apps/quadruple)

build-market-spread: ## build market spread app
	$(call PONYC,apps/market-spread)

build-word-count: ## build word count app
	$(call PONYC,apps/word-count)

build-word-length-count: ## build word length count app
	$(call PONYC,apps/word-length-count)

build-dagon: ## build dagon
	$(call PONYC,dagon)

build-dagon-child: ## build dagon-child
	$(call PONYC,dagon/dagon-child)

build-wesley: ## Build wesley
	$(call PONYC,wesley/word-length-count-test)
	$(call PONYC,wesley/double-test)
	$(call PONYC,wesley/identity-test)
	$(call PONYC,wesley/wordcount-test)
	$(call PONYC,wesley/market-spread-test)

build-metrics-reporter-ui: monhub-arch-check## Build Metrics Reporter UI
	$(call MONHUBC,monitoring_hub/apps/metrics_reporter_ui)

build-market-spread-reports-ui: monhub-arch-check## Build Market Spread Reports UI
	$(call MONHUBC,monitoring_hub/apps/market_spread_reports_ui)

build-fallor: ## build fallor decoder
	$(call PONYC,fallor)

test: test-double-divide test-avg-of-avgs test-state-avg-of-avgs test-quadruple test-market-spread test-word-count test-giles-receiver test-giles-sender ## Test programs for Buffy

test-double-divide: ## Test Double-Divide app
	cd apps/double-divide && ./double-divide

test-avg-of-avgs: ## Test avg-of-avgs app
	cd apps/avg-of-avgs && ./avg-of-avgs

test-state-avg-of-avgs: ## Test state-avg-of-avgs app
	cd apps/state-avg-of-avgs && ./state-avg-of-avgs

test-quadruple: ## Test quadruple app
	cd apps/quadruple && ./quadruple

test-market-spread: ## Test market-spread app
	cd apps/market-spread && ./market-spread

test-word-count: ## Test word-count app
	cd apps/word-count && ./word-count

test-word-length-count: ## Test word-length-count app
	cd apps/word-length-count && ./word-length-count

test-giles-receiver: ## Test Giles Receiver
	cd giles/receiver && ./receiver

test-giles-sender: ## Test Giles Sender
	cd giles/sender && ./sender

test-monitoring-hub: ## Test all Apps within the Monitoring Hub
	cd monitoring_hub && mix deps.get && mix test

test-monitoring-hub-utils: ## Test Monitoring Hub Utils
	cd monitoring_hub/apps/monitoring_hub_utils && mix test

test-mh-market-spread-reports: ## Test MH Market Spread Reports
	cd monitoring_hub/apps/market_spread_reports && mix test

test-mh-market-spread-reports-ui: ## Test MH Market Spread Reports UI
	cd monitoring_hub/apps/market_spread_reports_ui && mix test

test-mh-metrics-reporter: ## Test MH Metrics Reporter
	cd monitoring_hub/apps/metrics_reporter && mix test

test-mh-metrics-reporter-ui: ## Test MH Metrics Reporter UI
	cd monitoring_hub/apps/metrics_reporter_ui && mix test

dagon-test: dagon-identity dagon-word-count dagon-market-spread #dagon-word-length-count ## Run dagon tests

dagon-spike-test: dagon-identity-drop ## Run dagon spike tests

dagon-identity: ## Run identity test with dagon
	./dagon/dagon --timeout=15 -f apps/double-divide/double-divide.ini -h 127.0.0.1:8080
	./wesley/identity-test/identity-test ./sent.txt ./received.txt match

dagon-identity-drop: ## Run identity test with dagon
	./dagon/dagon --timeout=15 -f apps/double-divide/double-divide-drop.ini -h 127.0.0.1:8080
	./wesley/identity-test/identity-test ./sent.txt ./received.txt match

dagon-word-count: ## Run word count test with dagon
	./dagon/dagon --timeout=15 -f apps/word-count/word-count.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-single: ## Run word count test with dagon
	./dagon/dagon --timeout=15 -f apps/word-count/word-count-single.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-3: ## Run 3 minute word count test with dagon
	./dagon/dagon --timeout=800 -f apps/word-count/3-min-run.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-3-single: ## Run 7 minute word count test with dagon
	./dagon/dagon --timeout=800 -f apps/word-count/3-min-run-single.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-7: ## Run 7 minute word count test with dagon
	./dagon/dagon --timeout=3200 -f apps/word-count/7-min-run.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-7-single: ## Run 7 minute word count test with dagon
	./dagon/dagon --timeout=30 -f apps/word-count/7-min-run-single.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-15: ## Run 15 minute word count test with dagon
	./dagon/dagon --timeout=3200 -f apps/word-count/15-min-run.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-30: ## Run word count test with dagon
	./dagon/dagon --timeout=3200 -f apps/word-count/30-min-run.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match

dagon-word-count-60: ## Run word count test with dagon
	./dagon/dagon --timeout=6400 -f apps/word-count/60-min-run.ini -h 127.0.0.1:8080
	./wesley/wordcount-test/wordcount-test ./sent.txt ./received.txt match	

dagon-market-spread: ## Run market spread test with dagon
	./dagon/dagon --timeout=25 -f apps/market-spread/market-spread.ini -h 127.0.0.1:8080
	./wesley/market-spread-test/market-spread-test ./demos/marketspread/100nbbo.msg ./sent.txt ./received.txt match

dagon-word-length-count: ## Run word length count test with dagon
	./dagon/dagon --timeout=15 -f apps/word-length-count/word-length-count.ini -h 127.0.0.1:8080
	./wesley/word-length-count-test/word-length-count-test ./sent.txt ./received.txt match

build-docker: docker-arch-check ## Build docker images for Buffy
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/giles-receiver.$(arch):$(docker_image_version) \
          giles/receiver
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/giles-sender.$(arch):$(docker_image_version) \
          giles/sender
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/dagon.$(arch):$(docker_image_version) dagon
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/wesley-double.$(arch):$(docker_image_version) \
          wesley/double-test
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/wesley-identity.$(arch):$(docker_image_version) \
          wesley/identity-test
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/avg-of-avgs.$(arch):$(docker_image_version) \
          apps/avg-of-avgs
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/state-avg-of-avgs.$(arch):$(docker_image_version) \
          apps/state-avg-of-avgs
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/double-divide.$(arch):$(docker_image_version) \
          apps/double-divide
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/quadruple.$(arch):$(docker_image_version) \
          apps/quadruple
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/market-spread.$(arch):$(docker_image_version) \
          apps/market-spread
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/word-count.$(arch):$(docker_image_version) \
          apps/word-count
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/dagon-child.$(arch):$(docker_image_version) \
          dagon/dagon-child

push-docker: build-docker ## Push docker images for Buffy to repository
	docker $(docker_host_arg) push \
          $(docker_image_repo)/giles-receiver.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/giles-sender.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/dagon.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/wesley-double.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/wesley-identity.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/avg-of-avgs.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/state-avg-of-avgs.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/double-divide.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/quadruple.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/market-spread.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/word-count.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/dagon-child.$(arch):$(docker_image_version)

build-market-spread-reports-ui-docker:
	docker $(docker_host_arg) build -t \
		$(docker_image_repo)/monitoring_hub/apps/market_spread_reports_ui.$(arch):$(docker_image_version) \
		monitoring_hub/apps/market_spread_reports_ui

build-metrics-reporter-ui-docker:
	docker $(docker_host_arg) build -t \
		$(docker_image_repo)/monitoring_hub/apps/metrics_reporter_ui.$(arch):$(docker_image_version) \
		monitoring_hub/apps/metrics_reporter_ui

push-monitoring-hub-ui-docker: build-market-spread-reports-ui-docker build-metrics-reporter-ui-docker ## Push docker images for Market Spread Reports UI to repository
	docker $(docker_host_arg) push \
		$(docker_image_repo)/monitoring_hub/apps/market_spread_reports_ui.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
		$(docker_image_repo)/monitoring_hub/apps/metrics_reporter_ui.$(arch):$(docker_image_version)

exited := $(shell docker $(docker_host_arg) ps -a -q -f status=exited)
untagged := $(shell (docker $(docker_host_arg) images | grep "^<none>" | awk \
              -F " " '{print $$3}'))
dangling := $(shell docker $(docker_host_arg) images -f "dangling=true" -q)
tag := $(shell docker $(docker_host_arg) images | grep \
         "$(docker_image_version)" | awk -F " " '{print $$1 ":" $$2}')

clean-docker: ## cleanup docker images and containers
ifneq ($(strip $(exited)),)
	@echo "Cleaning exited containers: $(exited)"
	docker $(docker_host_arg) rm -v $(exited)
endif
ifneq ($(strip $(tag)),)
	@echo "Removing tag $(tag) image"
	docker $(docker_host_arg) rmi $(tag)
endif
ifneq ($(strip $(dangling)),)
	@echo "Cleaning dangling images: $(dangling)"
	docker $(docker_host_arg) rmi $(dangling)
endif

clean: clean-docker ## Cleanup docker images, deps and compiled files for Buffy
	find . -type d -name .deps -print -exec rm -rf {} \;
	rm -f giles/receiver/receiver giles/receiver/receiver.o
	rm -f giles/sender/sender giles/sender/sender.o
	rm -f dagon/dagon dagon/dagon.o
	rm -f wesley/identity-test/identity-test wesley/identity-test/identity-test.o
	rm -f wesley/double-test/double-test wesley/double-test/double-test.o
	rm -f wesley/wordcount-test/wordcount-test wesley/wordcount-test/wordcount-test.o
	rm -f wesley/market-spread-test/market-spread-test wesley/market-spread-test/market-spread-test.o
	rm -f lib/buffy/buffy lib/buffy/buffy.o
	rm -f sent.txt received.txt
	rm -f apps/avg-of-avgs/avg-of-avgs apps/avg-of-avgs/avg-of-avgs.o
	rm -f apps/state-avg-of-avgs/state-avg-of-avgs apps/state-avg-of-avgs/state-avg-of-avgs.o
	rm -f apps/double-divide/double-divide apps/double-divide/double-divide.o
	rm -f apps/quadruple/quadruple apps/quadruple/quadruple.o
	rm -f apps/market-spread/market-spread apps/market-spread/market-spread.o
	rm -f apps/word-count/word-count apps/word-count/word-count.o
	rm -f apps/word-length-count/word-length-count apps/word-length-count/word-length-count.o apps/word-length-count/*.class
	rm -f dagon/dagon-child/dagon-child dagon/dagon-child/dagon-child.o
	rm -rf monitoring_hub/apps/metrics_reporter_ui/rel/metrics_reporter_ui/
	rm -rf monitoring_hub/apps/market_spread_reports_ui/rel/market_spread_reports_ui/
	@echo 'Done cleaning.'

help:
	@echo 'Usage: make [option1=value] [option2=value,...] [target]'
	@echo ''
	@echo 'Options:'
	@grep -E '^[a-zA-Z_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "$(extra_awk_arg)?="}; {printf "\033[36m%-30s\033[0m ##%s\n", $$1, \
          $$2}' | awk 'BEGIN {FS = "## "}; {printf "%s %s \033[36m(Default:\
 %s)\033[0m\n", $$1, $$3, $$2}'
	@grep -E 'filter.*arch.*\)$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-30s\033[0m %s\n", \
          "  Valid values for " $$5 ":", $$7}'
	@grep -E 'filter.*in_docker.*\)$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "[(),]"}; {printf "\033[36m%-30s\033[0m %s\n", \
          "  Valid values for " $$5 ":", $$7}'
	@echo ''
	@echo 'Targets:'
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", \
          $$1, $$2}'
