#! /bin/bash

set -o errexit
set -o nounset

verify_args() {
  ## Verifies that the documentation release is being run for the provided args for
  ## version and commit
  echo "Creating documentation for version $for_version with commit $commit"
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
  # determine remote branch to use
  echo "Verifying that script is being run on a branch with a remote repo..."
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ "$BRANCH" == "master" ]]
  then
    remote_branch=master
    DOCKER_VERSION=$(< VERSION)
    DOCKER_URL="release\/wallaroo:$DOCKER_VERSION"
  elif [[ "$BRANCH" == "release" ]]
  then
    remote_branch=release
    DOCKER_VERSION=$(< VERSION)
    DOCKER_URL="release\/wallaroo:$DOCKER_VERSION"
  elif [[ "$BRANCH" == *"release-"* ]]
  then
    remote_branch=rc
    DOCKER_VERSION=$(< VERSION)-$(git log -n 1 --oneline | cut -d' ' -f1)
    DOCKER_URL="dev\/wallaroo:$DOCKER_VERSION"
  else
    echo "No remote repo to push book to. Exiting"
    exit 0
  fi
}

verify_commit_on_branch() {
  echo "Verfying commit $commit is on branch: $BRANCH..."
  if ! git branch --contains "$commit" | grep "$BRANCH"
  then
    echo "Commit $commit is not on branch: $BRANCH"
    exit 1
  fi
}

checkout_to_commit() {
  git checkout "$commit"
}

update_version() {
  echo "Updating version for docker image in config.toml..."
  # Update docker version in config.toml
  sed -i "s/^docker_version_url=.*/docker_version_url=\"${DOCKER_URL}\"/" documentation/config.toml
}

build_book() {
  echo "Building book..."
  pushd documentation/themes/ananke
  git submodule init
  git submodule update
  popd
  pushd documentation
  hugo
  popd
}

upload_book() {
  echo "Uploading book..."
  # git magic. without all this, our ghp-import command won't work
  pushd documentation
  git remote add doc-site "git@github.com:wallaroolabs/docs.wallaroolabs.com.git"
  git fetch doc-site
  git reset doc-site/$remote_branch

  ghp-import -p -r doc-site -b $remote_branch -f public

  popd
}

git_clean() {
  echo "Cleaning repo..."
  git clean -fd
  git remote rm doc-site
  echo "Checking out to $BRANCH"
  git reset --hard "origin/$BRANCH"
  git checkout "$BRANCH"
}

if [ $# -lt 2 ]; then
  echo "version and commit arguments required"
fi

set -eu
for_version=$1
commit=$2

verify_args
verify_branch
verify_commit_on_branch
checkout_to_commit
update_version
build_book
upload_book
git_clean
