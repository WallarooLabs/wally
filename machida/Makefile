# include root makefile
ifndef ROOT_MAKEFILE_MK
include ../Makefile
endif

# prevent rules from being evaluated/included multiple times
ifndef $(abspath $(lastword $(MAKEFILE_LIST)))_MK
$(abspath $(lastword $(MAKEFILE_LIST)))_MK := 1

# uncomment to disable generate test related targets in this directory
TEST_TARGET := false

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
RECURSE_SUBMAKEFILES := false

# standard rules generation makefile
include $(rules_mk_path)


# Set up our machida specific paths. We don't know what directory make was
# run from, so we get an absolute path based on $(wallaroo_path). This will work
# whether make was run from the top level of Wallaroo or from within the
# machida directory.
MACHIDA_PATH = $(wallaroo_path)/machida
MACHIDA_BUILD = $(MACHIDA_PATH)/build
MACHIDA_CPP = $(MACHIDA_PATH)/cpp
WALLAROO_LIB =  $(wallaroo_path)/lib

# Our top level Makefile has 3 rules that would have been generated for us if
# we hadn't turned them off at the top of the Makefile. Here we recreate them
# with our own custom rules. This allows the top level commands like
# "make test" to work.
build-machida: machida_build
test-machida: build-machida
clean-machida: machida_clean

machida_clean:
	rm -rf $(MACHIDA_BUILD)

machida_build: $(MACHIDA_BUILD)/machida

-include $(MACHIDA_PATH)/machida.d
$(MACHIDA_BUILD)/machida: $(MACHIDA_BUILD)/libpython-wallaroo.a
	$(eval original_PONYCFLAGS := $(PONYCFLAGS))
	$(eval PONYCFLAGS := $(original_PONYCFLAGS) -D resilience -D spike -D spiketrace --output=$(MACHIDA_BUILD) --path=$(MACHIDA_BUILD))
	$(call PONYC,$(abspath $(MACHIDA_PATH:%/=%)))
	mv $(abspath $(MACHIDA_BUILD:%/=%))/machida $(abspath $(MACHIDA_BUILD:%/=%))/machida_resilience
	$(eval PONYCFLAGS := $(original_PONYCFLAGS) --output=$(MACHIDA_BUILD) --path=$(MACHIDA_BUILD))
	$(call PONYC,$(abspath $(MACHIDA_PATH:%/=%)))
	$(eval PONYCFLAGS := $(original_PONYCFLAGS))

$(MACHIDA_BUILD)/libpython-wallaroo.a: $(MACHIDA_BUILD)/python-wallaroo.o
	ar rvs $(MACHIDA_BUILD)/libpython-wallaroo.a $(MACHIDA_BUILD)/python-wallaroo.o

$(MACHIDA_BUILD)/python-wallaroo.o: $(MACHIDA_CPP)/python-wallaroo.c
	mkdir -p $(MACHIDA_BUILD)
	cc -g -o $(MACHIDA_BUILD)/python-wallaroo.o -c $(MACHIDA_CPP)/python-wallaroo.c

# end of prevent rules from being evaluated/included multiple times
endif
