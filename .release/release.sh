#!/bin/bash

set -o errexit
set -o nounset

verify_args() {
  echo "Promoting a release candidate  to a release for branch $for_branch and version $for_version"
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
    echo "Provided branch: $rc_branch_name but running release promotion script on branch: $BRANCH."
    echo "Make sure you are on the branch you provide before running this script."
    exit 1
  fi
}

check_for_uncommited_changes() {
  if ! git diff-index --quiet HEAD --; then
    printf "Uncommited changes to your repo have been made."
    printf "Please commit your changes and push before running this script."
    exit 1
  fi
}

check_for_local_only_changes() {
  if ! git diff --exit-code "$rc_branch_name" "origin/$rc_branch_name"
  then
    echo "ERROR! There are local-only changes on branch '$rc_branch_name'!"
    exit 1
  fi
}

verify_changelog() {
  changelog_verify_result=$(changelog-tool verify CHANGELOG.md)
  if [[ $changelog_verify_result != *"CHANGELOG.md is a valid changelog"* ]]
  then
    echo "CHANGELOG is not valid, make sure it is valid prior to running this script."
    exit 1
  fi
}


update_version() {
  echo "$version" > VERSION
  echo "VERSION set to $version"
  echo "Replacing Wallaroo version in Vagrant bootstrap.sh with $version"
  find vagrant -name "bootstrap.sh" -exec sed -i -- "/WALLAROO_VERSION/ s/=\"[^\"][^\"]*\"/=\"$version\"/" {} \;
}

commit_version_update() {
  # commit VERSION update
  git add VERSION
  git commit -m "Update version for $version release"
}

update_version_in_changelog() {
  ## Updates the unreleased section to the version provided
  changelog-tool release CHANGELOG.md $for_version -e
}

commit_changelog_update() {
  ## Commit CHANGELOG update
  git add CHANGELOG.md
  git commit -m "Version CHANGELOG to $for_version"
}

push_rc_changes() {
  # push the release candidate branch
  git push origin "$rc_branch_name"
}

checkout_and_pull_release_branch() {
  git checkout origin/release
  git pull
  if ! git diff --exit-code release origin/release
  then
    echo "ERROR! There are local-only changes on branch 'release'!"
    exit 1
  fi
}

merge_rc_branch_into_release() {
  merge_result=$(git merge "origin/$rc_branch_name")
  if ! $merge_result; then
    printf "There was a merge conflict, please resolve manually and push to"
    printf "the `release` branch once resolved."
    exit 1
  fi
}

push_release_branch() {
  ## Push `release` branch
  git push origin/release
}

verify_push() {
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
  git tag "$for_version" release
  git push origin "$for_version"
}

release_gitbook() {
  .release/gitbookrelease.sh
}

release_docker_images() {
  .release/docker-release.sh
}

if [ $# -lt 2 ]; then
  echo "release candidate branch and version arguments required"
fi

set -eu
rc_branch_name=$1
for_version=$2

## Scripted process for promoting release candidate branch
## to a release branch
verify_args
verify_branch
check_for_uncommited_changes
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
