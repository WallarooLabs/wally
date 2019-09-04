#!/bin/bash
#
# Builds and publishing a public AMI with Wallaroo.
#
# This script runs in the Vagrant release box
# ami/initial_system_setup.sh run *on the machine that will be the AMI*.
#
# Usage:
# WALLAROO_ROOT$ ./.release/ami-release <branch_to_build> <ami_version_to_tag>

set -eu
RC_BRANCH_NAME=$1
FOR_VERSION=$2

compile_for_sandy_bridge() {
  PREV_HEAD=$(git rev-parse --abbrev-ref HEAD)
  TARGET_CPU=sandybridge
  PONYC_OPTS='target_cpu=${TARGET_CPU}'
  git checkout "$RC_BRANCH_NAME"
  make clean

  make build-machida3 "$PONYC_OPTS" resilience=on
  mv machida3/build/machida3 machida3-resilience
  make clean-machida3
  make build-machida3 "$PONYC_OPTS" resilience=off
  (cd utils/data_receiver && make "$PONYC_OPTS")
  (cd utils/cluster_shutdown && make "$PONYC_OPTS")
  (cd utils/cluster_shrinker && make "$PONYC_OPTS")
  (cd giles/sender && make "$PONYC_OPTS")

  zip -j9 .release/wallaroo_bin.zip \
      machida3/build/machida3 \
      machida3-resilience \
      utils/data_receiver/data_receiver \
      utils/cluster_shutdown/cluster_shutdown \
      utils/cluster_shrinker/cluster_shrinker \
      giles/sender/sender \
      testing/tools/dos-dumb-object-service/dos-server.py \
      testing/tools/dos-dumb-object-service/journal-dump.py
  echo "------ Wallaroo binaries compiled for ${TARGET_CPU}"
  git checkout "$PREV_HEAD"
}


build_ami_with_packer() {
  (cd .release &&
    REGIONS=$(echo -n "$(cat ami/regions)" | tr '\n' ',')
    for cmd in validate build; do
      packer ${cmd} \
         -var "ami_regions=${REGIONS}" \
         -var "wallaroo_version=${FOR_VERSION}" \
         ami/template.json
    done
  )
}

compile_for_sandy_bridge
build_ami_with_packer
