#!/bin/bash

set -o errexit
set -o nounset

if [ $# -lt 2 ]; then
  echo "version and commit arguments required"
  exit 1
fi

set -eu
for_version=$1
commit=$2

## Verifies that the release artifacts are being built for the provided args for
## version and commit
echo "Creating artifacts for version $for_version with commit $commit"
while true; do
  read -rp "Is this correct (y/n)?" yn
  case $yn in
  [Yy]*) break;;
  [Nn]*) exit;;
  *) echo "Please answer y or n.";;
  esac
done

HERE=$(dirname "$(readlink -f "${0}")")
echo y | "$HERE/bintray-artifacts-release.sh" "$for_version" "$commit"
echo y | "$HERE/docker-release.sh" "$for_version" "$commit"
echo y | "$HERE/documentation-release.sh" "$for_version" "$commit"
