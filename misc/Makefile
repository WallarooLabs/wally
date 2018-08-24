build-misc-all:
unit-tests-misc-all:
integration-tests-misc-all:
push-docker-misc-all:
build-docker-misc-all:
clean-misc-all:

ifeq ($(wallaroo_path),)
  WALLAROO_UP_PATH := $(CURDIR)
else
  WALLAROO_UP_PATH := $(wallaroo_path)/misc
endif
WALLAROO_UP_DISTROS_DOCKER:=debian-jessie debian-stretch ubuntu-trusty ubuntu-xenial ubuntu-bionic ubuntu-artful centos-7 fedora-26 fedora-27 fedora-28 debian-buster amazonlinux-2 oraclelinux-7
WALLAROO_UP_DISTROS_VAGRANT:=debian-jessie64 debian-stretch64 ubuntu-trusty64 ubuntu-xenial64 ubuntu-bionic64 ubuntu-artful64 centos-7 fedora-26-cloud-base fedora-27-cloud-base fedora-28-cloud-base gbailey-amzn2 generic-oracle7 debian-testing64
TEST_WALLAROO_UP_SUPPORTED_DISTROS_DOCKER:=$(addprefix test-wallaroo-up-docker-,$(WALLAROO_UP_DISTROS_DOCKER))
TEST_WALLAROO_UP_SUPPORTED_DISTROS_VAGRANT:=$(addprefix test-wallaroo-up-vagrant-,$(WALLAROO_UP_DISTROS_VAGRANT))

ifeq ($(shell uname -s),Linux)
  WALLAROO_UP_SED_ARGS=-i
else
  WALLAROO_UP_SED_ARGS=-i ""
endif

.PHONY: test-wallaroo-up-docker test-wallaroo-up-vagrant
# TODO: Add ability to run all and then produce a report after of which ones failed... maybe this is already possible via make?
test-wallaroo-up-docker: $(TEST_WALLAROO_UP_SUPPORTED_DISTROS_DOCKER)
test-wallaroo-up-vagrant: $(TEST_WALLAROO_UP_SUPPORTED_DISTROS_VAGRANT)

test-wallaroo-up: test-wallaroo-up-docker test-wallaroo-up-vagrant

test-wallaroo-up-docker-%:
	$(QUIET)docker run \
		--rm \
		-v $(WALLAROO_UP_PATH)/..:/v \
		-w /v \
		--name wally-tester \
		$(subst -,:,$*) sh -c \
		'(export CUSTOM_WALLAROO_SOURCE_TGZ_URL=$(CUSTOM_WALLAROO_SOURCE_TGZ_URL) && export CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL=$(CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL) && echo y | /v/misc/wallaroo-up.sh -t all || (tail -n 100 wallaroo-up.log && exit 1)) && ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash python && ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash go'
	$(QUIET)docker rmi $(subst -,:,$*)

test-wallaroo-up-vagrant-%:
	$(QUIET)cd $(WALLAROO_UP_PATH) && vagrant destroy -f
	$(QUIET)cd $(WALLAROO_UP_PATH) && rm -f Vagrantfile
	$(QUIET)cd $(WALLAROO_UP_PATH) && vagrant init $(shell echo $* | sed 's#-#/#')
	$(QUIET)cd $(WALLAROO_UP_PATH) && sed $(WALLAROO_UP_SED_ARGS) -e 's@^end@  config.vm.synced_folder "../", "/v";  config.vm.provider "virtualbox" do |vb|    vb.memory = 4084  end  end@' Vagrantfile
	$(QUIET)cd $(WALLAROO_UP_PATH) && vagrant up
	$(QUIET)cd $(WALLAROO_UP_PATH) && vagrant ssh -c \
		'(export CUSTOM_WALLAROO_SOURCE_TGZ_URL=$(CUSTOM_WALLAROO_SOURCE_TGZ_URL) && export CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL=$(CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL) && echo y | /v/misc/wallaroo-up.sh -t all || (tail -n 100 wallaroo-up.log && exit 1)) && ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash python && ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash go'
	$(QUIET)cd $(WALLAROO_UP_PATH) && vagrant destroy -f
	$(QUIET)cd $(WALLAROO_UP_PATH) && rm -f Vagrantfile
