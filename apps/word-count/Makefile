rules_mk_path := ../../rules.mk

# uncomment to disable generate pony related targets (build/test/clean) for pony sources in this directory
#PONY_TARGET := false

# uncomment to disable generate exs related targets (build/test/clean) for elixir sources in this directory
#EXS_TARGET := false

# uncomment to disable generate docker related targets (build/push) for Dockerfile in this directory
#DOCKER_TARGET := false

# uncomment to disable generate recursing into Makefiles of subdirectories
#RECURSE_SUBMAKEFILES := false



#########################################################################################
#### don't change after this line unless to disable standard rules generation makefile
MY_NAME := $(lastword $(MAKEFILE_LIST))
$(MY_NAME)_PATH := $(dir $(MY_NAME))

include $($(MY_NAME)_PATH:%/=%)/$(rules_mk_path)
#### don't change before this line unless to disable standard rules generation makefile
#########################################################################################


# args to RUN_DAGON and RUN_DAGON_SPIKE: $1 = test name; $2 = ini file; $3 = timeout; $4 = wesley test command, $5 = include in CI
# NOTE: all paths must be relative to buffy directory (use buffy_path variable)

#dagon-word-count: #used as part of `make help` command ## Run word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count \
,$(buffy_path)/apps/word-count/word-count.ini \
,15 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,true))

#dagon-word-count-single: #used as part of `make help` command ## Run word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-single \
,$(buffy_path)/apps/word-count/word-count-single.ini \
,15 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-3: #used as part of `make help` command ## Run 3 minute word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-3 \
,$(buffy_path)/apps/word-count/3-min-run.ini \
,800 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-3-single: #used as part of `make help` command ## Run 7 minute word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-3-single \
,$(buffy_path)/apps/word-count/3-min-run-single.ini \
,800 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-7: #used as part of `make help` command ## Run 7 minute word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-7 \
,$(buffy_path)/apps/word-count/7-min-run.ini \
,3200 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-7-single: #used as part of `make help` command ## Run 7 minute word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-7-single \
,$(buffy_path)/apps/word-count/7-min-run-single.ini \
,3200 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-15: #used as part of `make help` command ## Run 15 minute word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-15 \
,$(buffy_path)/apps/word-count/15-min-run.ini \
,3200 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-30: #used as part of `make help` command ## Run word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-30 \
,$(buffy_path)/apps/word-count/30-min-run.ini \
,3200 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

#dagon-word-count-60: #used as part of `make help` command ## Run word count test with dagon
$(eval $(call RUN_DAGON\
,dagon-word-count-60 \
,$(buffy_path)/apps/word-count/60-min-run.ini \
,6400 \
,$(buffy_path)/wesley/wordcount-test/wordcount-test $(buffy_path)/sent.txt $(buffy_path)/received.txt match \
,false))

