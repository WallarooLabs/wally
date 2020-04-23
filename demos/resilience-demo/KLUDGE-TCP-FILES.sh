#!/bin/sh

. ./COMMON.sh

# Wallaroo changed its work file naming scheme.
# Let's try to figure out what the new scheme is.
WALLAROO_NAME_BASE=`ssh -n $USER@$SERVER1_EXT "ls /tmp/*initializer*.evlog | sed \"s:.*/\([^-]*\)-.*:\1:\""`
echo WALLAROO_NAME_BASE is $WALLAROO_NAME_BASE

ssh -n $USER@$TARGET_EXT "(echo $TARGET ; echo 3131) > \"/tmp/${WALLAROO_NAME_BASE}-worker${SOURCE_WORKER}.tcp-control\" ; (echo $TARGET ; echo 3132) > \"/tmp/${WALLAROO_NAME_BASE}-worker${SOURCE_WORKER}.tcp-data\""
