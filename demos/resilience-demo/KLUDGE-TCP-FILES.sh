#!/bin/sh

. ./COMMON.sh

ssh -n $USER@$TARGET_EXT "(echo $TARGET ; echo ${SOURCE_WORKER}3131) > /tmp/${WALLAROO_NAME}-worker${SOURCE_WORKER}.tcp-control ; (echo $TARGET ; echo ${SOURCE_WORKER}3132) > /tmp/${WALLAROO_NAME}-worker${SOURCE_WORKER}.tcp-data"
