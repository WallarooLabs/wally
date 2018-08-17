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

HERE=$(dirname "$(readlink -f "${0}")")
"$HERE/bintray-artifacts-release.sh" "$for_version" "$commit"
"$HERE/docker-release.sh" "$for_version" "$commit"
"$HERE/gitbook-release.sh" "$for_version" "$commit"
