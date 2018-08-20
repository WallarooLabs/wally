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
WALLAROO_UP_DISTROS:=debian-jessie debian-stretch debian-buster ubuntu-trusty ubuntu-xenial ubuntu-bionic ubuntu-artful centos-7 fedora-26 fedora-27 fedora-28
TEST_WALLAROO_UP_SUPPORTED_DISTROS:=$(addprefix test-wallaroo-up-,$(WALLAROO_UP_DISTROS))

.PHONY: test-wallaroo-up clean-wallaroo-up
test-wallaroo-up: $(TEST_WALLAROO_UP_SUPPORTED_DISTROS)

test-wallaroo-up-%:
	$(QUIET)docker run \
		--rm \
		-v $(WALLAROO_UP_PATH):/v \
		-w /v \
		$(subst -,:,$*) \
		sh -c '(echo y | /v/wallaroo-up.sh -t all || (tail -n 100 /v/wallaroo-up.log && exit 1)) && ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash python && ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash go' && docker rmi $(subst -,:,$*)
