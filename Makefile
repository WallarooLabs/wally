current_dir = $(shell pwd)
latest_ponyc_tag = $(shell curl -s \
  https://hub.docker.com/r/sendence/ponyc/tags/ | grep -o \
  'sendence-[0-9.-]*-release-' | sed 's/sendence-\([0-9.-]*\)-release-/\1/' \
  | sort -un | tail -n 1)# latest ponyc tag
docker_image_version ?= $(shell git describe --tags --always)## Docker Image Tag to use
docker_image_repo ?= docker.sendence.com:5043/sendence## Docker Repository to use
arch ?= native## Architecture to build for
in_docker ?= false## Whether already in docker or not (used by CI)
ponyc_tag ?= sendence-$(latest_ponyc_tag)-debug## tag for ponyc docker to use
ponyc_runner ?= sendence/ponyc## ponyc docker image to use
docker_no_pull ?= false## Don't pull docker images for dagon run
docker_no_pull_arg =# Final argument string for docker no pull
docker_host ?= unix:///var/run/docker.sock## docker host to build/run containers on
docker_host_arg = --host=$(docker_host)# docker host argument

ifdef docker_no_pull
  ifeq (,$(filter $(docker_no_pull),false true))
    $(error Unknown docker_no_pull option "$(docker_no_pull)")
  endif
endif

ifeq ($(docker_no_pull),true)
  docker_no_pull_arg=--no_docker_pull
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

ifeq ($(in_docker),true)
  ifeq ($(arch),armhf)
    define PONYC
      cd $(current_dir)/$(1) && stable fetch
      cd $(current_dir)/$(1) && stable env ponyc \
        --triple arm-unknown-linux-gnueabihf -robj .
      cd $(current_dir)/$(1) && arm-linux-gnueabihf-gcc \
        -o `basename $(current_dir)/$(1)` \
        -O3 -march=armv7-a -flto -fuse-linker-plugin \
        -fuse-ld=gold \
        `basename $(current_dir)/$(1)`.o \
        -L"/usr/local/lib" \
        -L"/build/arm/ponyc/build/debug/" \
        -L"/build/arm/ponyc/build/release/" \
        -L"/build/arm/ponyc/packages" \
        -Wl,--start-group \
        -l"rt" \
        -Wl,--end-group  \
        -lponyrt -lpthread -ldl -lm
    endef
  else
    define PONYC
      cd $(current_dir)/$(1) && stable fetch
      cd $(current_dir)/$(1) && stable env ponyc .
    endef
  endif
else
  ifeq ($(arch),amd64)
    define PONYC
      docker run --rm -it -u `id -u` -v $(current_dir):$(current_dir) \
        -v ~/.gitconfig:/.gitconfig \
        -w $(current_dir)/$(1) --entrypoint stable \
        $(ponyc_runner):$(ponyc_tag)-$(arch) fetch
      docker run --rm -it -u `id -u` -v $(current_dir):$(current_dir) \
        -w $(current_dir)/$(1) --entrypoint stable \
        $(ponyc_runner):$(ponyc_tag)-$(arch) env ponyc .
    endef
  else ifeq ($(arch),armhf)
    define PONYC
      docker run --rm -it -u `id -u` -v \
        -v ~/.gitconfig:/.gitconfig \
        $(current_dir):$(current_dir) -w $(current_dir)/$(1) \
        --entrypoint stable $(ponyc_runner):$(ponyc_tag)-$(arch) \
        fetch
      docker run --rm -it -u `id -u` -v \
        $(current_dir):$(current_dir) -w $(current_dir)/$(1) \
        --entrypoint stable $(ponyc_runner):$(ponyc_tag)-$(arch) \
        env ponyc --triple arm-unknown-linux-gnueabihf -robj .
      docker run --rm -it -u `id -u` -v \
        $(current_dir):$(current_dir) -w $(current_dir)/$(1) \
        --entrypoint arm-linux-gnueabihf-gcc \
        $(ponyc_runner):$(ponyc_tag)-$(arch) \
        -o `basename $(current_dir)/$(1)` \
        -O3 -march=armv7-a -flto -fuse-linker-plugin \
        -fuse-ld=gold \
        `basename $(current_dir)/$(1)`.o \
        -L"/usr/local/lib" \
        -L"/build/arm/ponyc/build/debug/" \
        -L"/build/arm/ponyc/build/release/" \
        -L"/build/arm/ponyc/packages" \
        -Wl,--start-group \
        -l"rt" \
        -Wl,--end-group  \
        -lponyrt -lpthread -ldl -lm
    endef
  else
    define PONYC
      cd $(current_dir)/$(1) && stable fetch
      cd $(current_dir)/$(1) && stable env ponyc .
    endef
  endif
endif

default: build

print-%  : ; @echo $* = $($*)

build: build-spike build-receiver build-sender build-wesley build-buffy ## Build Pony based programs for Buffy

build-spike: ## Build spike
	$(call PONYC,spike)

build-receiver: ## Build giles receiver
	$(call PONYC,giles/receiver)

build-sender: ## Build giles sender
	$(call PONYC,giles/sender)

build-buffy: ## Build buffy
	$(call PONYC,buffy)

build-wesley: ## Build wesley
	$(call PONYC,wesley/double)
	$(call PONYC,wesley/identity)

test: test-buffy test-giles-receiver test-giles-sender ## Test programs for Buffy

test-buffy: ## Test buffy
	cd buffy && ./buffy

test-giles-receiver: ## Test Giles Receiver
	cd giles/receiver && ./receiver

test-giles-sender: ## Test Giles Sender
	cd giles/sender && ./sender

dagon-test: #dagon-identity dagon-double ## Run dagon tests

dagon-double: ## Run double test with dagon
	dagon/dagon.py dagon/config/double.ini
	wesley/double/double sent.txt received.txt \
          dagon/config/double.ini

dagon-identity: ## Run identity test with dagon
	dagon/dagon.py dagon/config/identity.ini
	wesley/identity/identity sent.txt received.txt \
          dagon/config/identity.ini

dagon-docker-test: #dagon-docker-identity dagon-docker-double ## Run dagon tests using docker

dagon-docker-double: ## Run double test with dagon
	docker $(docker_host_arg) ps -a | \
          grep dagon-container-$(docker_image_version) | \
          awk '{print $$1}' | xargs -r docker $(docker_host_arg) rm
	docker $(docker_host_arg) run -i --privileged --net=host -e \
          "LC_ALL=C.UTF-8" -e "LANG=C.UTF-8"  -v /bin:/bin:ro -v /lib:/lib:ro \
          -v /lib64:/lib64:ro -v /usr:/usr:ro -v /etc:/etc:ro -v \
          /var/run/docker.sock:/var/run/docker.sock  -v /root:/root:ro -v \
          /dagon/config -v \
          /tmp/dagon-$(docker_image_version):/tmp/dagon-$(docker_image_version)\
          -w /tmp/dagon-$(docker_image_version) --name \
          dagon-container-$(docker_image_version) \
          $(docker_image_repo)/dagon:$(docker_image_version) \
          /dagon/config/double.ini --docker_tag $(docker_image_version) \
          --docker $(docker_no_pull_arg)
	docker $(docker_host_arg) run --rm --privileged -i -v /bin:/bin:ro -v \
        /lib:/lib:ro -v /lib64:/lib64:ro  -v /usr:/usr:ro -v /etc:/etc:ro -v \
        /var/run/docker.sock:/var/run/docker.sock  -v /root:/root:ro -v \
        /tmp/dagon-$(docker_image_version):/tmp/dagon-$(docker_image_version) \
        -w /tmp/dagon-$(docker_image_version) \
        --volumes-from dagon-container-$(docker_image_version) \
        docker.sendence.com:5043/sendence/wesley-double.$(arch):$(docker_image_version) \
        sent.txt received.txt /dagon/config/double.ini
	docker $(docker_host_arg) ps -a | grep \
          dagon-container-$(docker_image_version) | awk '{print $$1}' | xargs \
          -r docker $(docker_host_arg) rm

dagon-docker-identity: ## Run identity test with dagon
	docker $(docker_host_arg) ps -a | grep \
          dagon-container-$(docker_image_version) | awk '{print $$1}' | xargs \
          -r docker $(docker_host_arg) rm
	docker $(docker_host_arg) run -i --privileged --net=host -e \
          "LC_ALL=C.UTF-8" -e "LANG=C.UTF-8"  -v /bin:/bin:ro -v /lib:/lib:ro \
          -v /lib64:/lib64:ro -v /usr:/usr:ro -v /etc:/etc:ro -v \
          /var/run/docker.sock:/var/run/docker.sock  -v /root:/root:ro -v \
          /dagon/config -v \
          /tmp/dagon-$(docker_image_version):/tmp/dagon-$(docker_image_version)\
          -w /tmp/dagon-$(docker_image_version) --name \
          dagon-container-$(docker_image_version) \
          $(docker_image_repo)/dagon:$(docker_image_version) \
          /dagon/config/identity.ini --docker_tag $(docker_image_version) \
          --docker $(docker_no_pull_arg)
	docker $(docker_host_arg) run --rm --privileged -i -v /bin:/bin:ro -v \
        /lib:/lib:ro -v /lib64:/lib64:ro  -v /usr:/usr:ro -v /etc:/etc:ro -v \
        /var/run/docker.sock:/var/run/docker.sock  -v /root:/root:ro -v \
        /tmp/dagon-$(docker_image_version):/tmp/dagon-$(docker_image_version) \
        -w /tmp/dagon-$(docker_image_version) \
        --volumes-from dagon-container-$(docker_image_version) \
        docker.sendence.com:5043/sendence/wesley-identity.$(arch):$(docker_image_version) \
        sent.txt received.txt /dagon/config/identity.ini
	docker $(docker_host_arg) ps -a | grep \
          dagon-container-$(docker_image_version) | awk '{print $$1}' | xargs \
          -r docker $(docker_host_arg) rm

build-docker:  ## Build docker images for Buffy
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/spike.$(arch):$(docker_image_version) spike
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/giles-receiver.$(arch):$(docker_image_version) \
          giles/receiver
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/giles-sender.$(arch):$(docker_image_version) \
          giles/sender
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/buffy.$(arch):$(docker_image_version) buffy
#	docker $(docker_host_arg) build -t \
#          $(docker_image_repo)/dagon.$(arch):$(docker_image_version) dagon
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/wesley-double.$(arch):$(docker_image_version) \
          wesley/double
	docker $(docker_host_arg) build -t \
          $(docker_image_repo)/wesley-identity.$(arch):$(docker_image_version) \
          wesley/identity

push-docker: build-docker ## Push docker images for Buffy to repository
	docker $(docker_host_arg) push \
          $(docker_image_repo)/spike.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/giles-receiver.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/giles-sender.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/buffy.$(arch):$(docker_image_version)
#	docker $(docker_host_arg) push \
#          $(docker_image_repo)/dagon.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/wesley-double.$(arch):$(docker_image_version)
	docker $(docker_host_arg) push \
          $(docker_image_repo)/wesley-identity.$(arch):$(docker_image_version)

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

clean: clean-docker ## Cleanup docker images and compiled files for Buffy
	rm -f spike/spike spike/spike.o
	rm -f giles/receiver/receiver giles/receiver/receiver.o
	rm -f giles/sender/sender giles/sender/sender.o
	rm -f wesley/identity/identity wesley/identity/identity.o
	rm -f wesley/double/double wesley/double/double.o
	rm -f buffy/buffy buffy/buffy.o
	rm -f sent.txt received.txt
	@echo 'Done cleaning.'

help:
	@echo 'Usage: make [option1=value] [option2=value,...] [target]'
	@echo ''
	@echo 'Options:'
	@grep -E '^[a-zA-Z_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "\?="}; {printf "\033[36m%-30s\033[0m ##%s\n", $$1, \
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

