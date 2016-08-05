#!/bin/bash 
set -euox pipefail

NUM_SYS_CPUS=${1:-}

if [ "${NUM_SYS_CPUS}" == "" ]; then
  echo "No cpu isolation specified. Nothing to do."
else
  echo "Isolating general system processes to cpus '0-$(($NUM_SYS_CPUS-1))'."
  echo "Current process map by cpuset:"
  cset set -l -r
  cset set -c 0-$(($NUM_SYS_CPUS-1)) -s system
  cset set -c ${NUM_SYS_CPUS}-$((`nproc --all`-1)) -s user
  cset proc -m -k --threads -f root -t system
  echo "Modified process map by cpuset:"
  cset set -l -r
  echo "Done isolating general system processes to cpus '0-$(($NUM_SYS_CPUS-1))'."
fi

