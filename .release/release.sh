#!/bin/bash

set -o errexit
set -o nounset

verify_args() {
  echo "Promoting a release candidate  to a release for branch $rc_branch_name and version $for_version"
  while true; do
    read -rp "Is this correct (y/n)?" yn
    case $yn in
    [Yy]*) break;;
    [Nn]*) exit;;
    *) echo "Please answer y or n.";;
    esac
  done
}

verify_branch() {
  ## Verifies that this script is being run on the provided release candidate branch
  echo "Verifying that script is being run on the provided release candidate branch..."
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ $BRANCH != "$rc_branch_name" ]]
  then
    echo "Provided branch: $rc_branch_name but running release promotion script on branch: $BRANCH."
    echo "Make sure you are on the branch you provide before running this script."
    exit 1
  fi
}

check_for_uncommitted_changes() {
  echo "Checking for uncommitted changes..."
  if ! git diff-index --quiet HEAD --; then
    printf "Uncommited changes to your repo have been made."
    printf "Please commit your changes and push before running this script."
    exit 1
  fi
}

check_for_local_only_changes() {
  echo "Checking for local only changes..."
  if ! git diff --exit-code "$rc_branch_name" "origin/$rc_branch_name"
  then
    echo "ERROR! There are local-only changes on branch '$rc_branch_name'!"
    exit 1
  fi
}

verify_changelog() {
  echo "Verifying CHANGELOG..."
  changelog_verify_result=$(changelog-tool verify CHANGELOG.md)
  if [[ $changelog_verify_result != *"CHANGELOG.md is a valid changelog"* ]]
  then
    echo "CHANGELOG is not valid, make sure it is valid prior to running this script."
    exit 1
  fi
}


update_version() {
  echo "Updating VERSION to $for_version..."
  echo "$for_version" > VERSION
  echo "VERSION set to $for_version"
  echo "Replacing Wallaroo version in Vagrant bootstrap.sh with $for_version"
  find vagrant -name "bootstrap.sh" -exec sed -i -- "/WALLAROO_VERSION/ s/=\"[^\"][^\"]*\"/=\"$for_version\"/" {} \;
  echo "Updating wallaroo-up.sh for $for_version"
  # default wallaroo-up.sh to this latest release
  sed -i "s/^WALLAROO_VERSION_DEFAULT=.*/WALLAROO_VERSION_DEFAULT=$for_version/" misc/wallaroo-up.sh
  # update GO Version in wallaroo-up.sh
  GO_VERSION=$(grep -Po '(?<=GO_VERSION=").*(?=")' .release/bootstrap.sh)
  sed -i 's/^GOLANG_VERSION=.*/GOLANG_VERSION=${GO_VERSION}/' misc/wallaroo-up.sh
  # add version to wallaroo-up.sh map
  PONYC_VERSION=$(grep -Po '(?<=PONYC_VERSION=").*(?=")' .release/bootstrap.sh)
  sed -i "s/WALLAROO_PONYC_MAP=\"/WALLAROO_PONYC_MAP=\"\nW${for_version}=${PONYC_VERSION}/" misc/wallaroo-up.sh
  # remove old release candidate versions from wallaroo-up.sh map
  sed -i "/Wrelease-/d" misc/wallaroo-up.sh
  # update activate script for latest release
  sed -i "s@^WALLAROO_ROOT=.*@WALLAROO_ROOT=\"\${HOME}/wallaroo-tutorial/wallaroo-${for_version}\"@" misc/activate
  # update activate script for golang version
  sed -i "s@^export GOROOT=.*@export GOROOT=\$WALLAROO_ROOT/bin/go${GO_VERSION}@" misc/activate
}

commit_version_update() {
  echo "Committing version change..."
  # commit VERSION update
  git add VERSION
  git add vagrant/bootstrap.sh
  git add misc/wallaroo-up.sh
  git add misc/activate
  git commit -m "Update version for $for_version release"
}

update_version_in_changelog() {
  echo "Updating version in CHANGELOG..."
  ## Updates the unreleased section to the version provided
  changelog-tool release CHANGELOG.md $for_version -e
}

commit_changelog_update() {
  echo "Committing CHANGELOG update..."
  ## Commit CHANGELOG update
  git add CHANGELOG.md
  git commit -m "Version CHANGELOG to $for_version"
}

push_rc_changes() {
  echo "Pushing chnages to $rc_branch_name"
  # push the release candidate branch
  git push origin "$rc_branch_name"
}

checkout_and_pull_release_branch() {
  echo "Checking out to release branch..."
  git checkout release
  git pull
  if ! git diff --exit-code release origin release
  then
    echo "ERROR! There are local-only changes on branch 'release'!"
    exit 1
  fi
}

merge_rc_branch_into_release() {
  echo "Merging $rc_branch_name with release branch..."
  merge_result=$(git merge "origin/$rc_branch_name")
  if ! $merge_result; then
    printf "There was a merge conflict, please resolve manually and push to"
    printf "the `release` branch once resolved."
    exit 1
  fi
}

push_release_branch() {
  echo "Pushing release branch..."
  ## Push `release` branch
  git push origin release
}

verify_push() {
  echo "Verifying push..."
  printf "Local changes to your repo have been made."
  printf "Would you like to commit and push to your origin repo (y/n)? "
  while true; do
    read -r yn
    case $yn in
    [Yy]*) break;;
    [Nn]*) exit;;
    *) echo "Please answer y or n.";;
    esac
  done
}

tag_and_push() {
  echo "Tagging and pushing $for_version tag..."
  git tag "$for_version" release
  git push origin "$for_version"
}

if [ $# -lt 2 ]; then
  echo "release candidate branch and version arguments required"
  exit 1
fi

set -eu
rc_branch_name=$1
for_version=$2

## Scripted process for promoting release candidate branch
## to a release branch
verify_args
verify_branch
check_for_uncommitted_changes
check_for_local_only_changes
verify_changelog
update_version
commit_version_update
update_version_in_changelog
commit_changelog_update
verify_push
push_rc_changes
checkout_and_pull_release_branch
merge_rc_branch_into_release
verify_push
push_release_branch
tag_and_push
