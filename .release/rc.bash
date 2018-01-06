#!/bin/bash

set -o errexit
set -o nounset

verify_args() {
  echo "Cutting a release candidate for version $for_version with commit $commit"
  while true; do
    read -rp "Is this correct (y/n)?" yn
    case $yn in
    [Yy]*) break;;
    [Nn]*) exit;;
    *) echo "Please answer y or n.";;
    esac
  done
}

check_for_commit_and_push() {
  printf "Local changes to your repo have been made."
  printf "Would you like commit and push to your origin repo (y/n)? "
  while true; do
    read -r yn
    case $yn in
    [Yy]*) break;;
    [Nn]*) exit;;
    *) echo "Please answer y or n.";;
    esac
  done
}

if [ $# -le 2 ]; then
  echo "version and commit arguments required"
fi

set -eu
for_version=$1
commit=$2

verify_args

# release candidate "version number" is "release-version" ie for 0.3.1
# the release candidate will use "release-0.3.1" as the version number
version=release-$for_version
# release candidate branch name is based on the version number.
# for version "0.3.1" the release candidate branch name would be "release-0.3.1"
rc_branch_name=release-$for_version

# create version release branch
git checkout master
git pull
if ! git diff --exit-code master origin/master
then
  echo "ERROR! There are local-only changes on branch 'master'!"
  exit 1
fi
git checkout -b "$rc_branch_name" "$commit"

update_version() {
  echo "$version" > VERSION
  echo "VERSION set to $version"
}

# update VERSION
update_version

# check if user wants to continue
check_for_commit_and_push

# commit VERSION update
git add VERSION
git commit -m "Create candidate for $version release"

# push the release candidate branch
git push origin "$rc_branch_name"
