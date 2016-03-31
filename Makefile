current_dir = $(shell pwd)
docker_image_version ?= $(shell git describe --tags --always)## Docker Image Tag to use
docker_image_repo ?= docker.sendence.com:5043/sendence## Docker Repository to use
arch ?= native## Architecture to build for
in_docker ?= false## Whether already in docker or not (used by CI)
ponyc_tag ?= sendence-2.1.0-debug## tag for ponyc docker to use
ponyc_runner ?= sendence/ponyc## ponyc docker image to use

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
      cd $(current_dir)/$(1) && ponyc --triple arm-unknown-linux-gnueabihf -robj .
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
      cd $(current_dir)/$(1) && ponyc .
    endef
  endif
else
  ifeq ($(arch),amd64)
    define PONYC
      docker run --rm -it -v $(current_dir)/$(1):$(current_dir)/$(1) \
        -w $(current_dir)/$(1) --entrypoint ponyc \
        $(ponyc_runner):$(ponyc_tag)-$(arch) .
    endef
  else ifeq ($(arch),armhf)
    define PONYC
      docker run --rm -it -u `id -u` -v \
        $(current_dir)/$(1):$(current_dir)/$(1) -w $(current_dir)/$(1) \
        --entrypoint ponyc $(ponyc_runner):$(ponyc_tag)-$(arch) \
        --triple arm-unknown-linux-gnueabihf -robj .
      docker run --rm -it -u `id -u` -v \
        $(current_dir)/$(1):$(current_dir)/$(1) -w $(current_dir)/$(1) \
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
      cd $(current_dir)/$(1) && ponyc .
    endef
  endif
endif

default: build

print-%  : ; @echo $* = $($*)

build: build-spike build-receiver build-sender build-wesley ## Build Pony based programs for Buffy

build-spike: ## Build spike
	$(call PONYC,spike)

build-receiver: ## Build giles receiver
	$(call PONYC,giles/receiver)

build-sender: ## Build giles sender
	$(call PONYC,giles/sender)

build-wesley: ## wesley
	$(call PONYC,wesley/double)
	$(call PONYC,wesley/identity)

test: lint-test test-buffy test-giles-receiver test-giles-sender ## Test programs for Buffy

test-buffy: ## Test buffy
	cd buffy && python3 -m py.test functions/*

test-giles-receiver: ## Test Giles Receiver
	cd giles/receiver && ./receiver

test-giles-sender: ## Test Giles Sender
	cd giles/sender && ./sender

lint-test: lint-test-buffy ## Run lint tests for programs for Buffy

lint-test-buffy: ## Run lint test buffy
	cd buffy && python3 -m pyflakes *.py functions/*.py

build-docker:  build ## Build docker images for Buffy
	docker build -t \
          $(docker_image_repo)/spike.$(arch):$(docker_image_version) spike
	docker build -t \
          $(docker_image_repo)/giles-receiver.$(arch):$(docker_image_version) \
          giles/receiver
	docker build -t \
          $(docker_image_repo)/giles-sender.$(arch):$(docker_image_version) \
          giles/sender
	docker build -t $(docker_image_repo)/buffy:$(docker_image_version) \
          buffy
	docker tag $(docker_image_repo)/buffy:$(docker_image_version) \
          $(docker_image_repo)/buffy.$(arch):$(docker_image_version)
	docker build -t $(docker_image_repo)/dagon:$(docker_image_version) \
          dagon
	docker tag $(docker_image_repo)/dagon:$(docker_image_version) \
          $(docker_image_repo)/dagon.$(arch):$(docker_image_version)

push-docker: build-docker ## Push docker images for Buffy to repository
	docker push $(docker_image_repo)/spike.$(arch):$(docker_image_version)
	docker push \
          $(docker_image_repo)/giles-receiver.$(arch):$(docker_image_version)
	docker push \
          $(docker_image_repo)/giles-sender.$(arch):$(docker_image_version)
	docker push $(docker_image_repo)/buffy:$(docker_image_version)
	docker push $(docker_image_repo)/buffy.$(arch):$(docker_image_version)
	docker push $(docker_image_repo)/dagon:$(docker_image_version)
	docker push $(docker_image_repo)/dagon.$(arch):$(docker_image_version)

exited := $(shell docker ps -a -q -f status=exited)
untagged := $(shell (docker images | grep "^<none>" | awk -F " " '{print $$3}'))
dangling := $(shell docker images -f "dangling=true" -q)
tag := $(shell docker images | grep "$(docker_image_version)" \
         |awk -F " " '{print $$3}')

clean: ## Cleanup docker images and compiled files for Buffy
	rm -f spike/spike spike/spike.o
	rm -f giles/receiver/receiver giles/receiver/receiver.o
	rm -f giles/sender/sender giles/sender/sender.o
	rm -f wesley/identity/identity wesley/identity/identity.o
	rm -f wesley/double/double wesley/double/double.o
ifneq ($(strip $(tag)),)
	@echo "Removing tag $(tag) image"
	docker rmi $(tag)
endif
ifneq ($(strip $(exited)),)
	@echo "Cleaning exited containers: $(exited)"
	docker rm -v $(exited)
endif
ifneq ($(strip $(dangling)),)
	@echo "Cleaning dangling images: $(dangling)"
	docker rmi $(dangling)
endif
	@echo 'Done cleaning.'

help:
	@echo 'Usage: make [option1=value] [option2=value,...] [target]'
	@echo ''
	@echo 'Options:'
	@grep -E '^[a-zA-Z_-]+ *\?=.*?## .*$$' $(MAKEFILE_LIST) | awk \
          'BEGIN {FS = "\?="}; {printf "\033[36m%-30s\033[0m ##%s\n", $$1, $$2}' \
          | awk 'BEGIN {FS = "## "}; {printf "%s %s \033[36m(Default: %s)\033[0m\n", $$1, $$3, $$2}'
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

