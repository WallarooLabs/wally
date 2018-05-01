#! /bin/bash

set -o errexit
set -o nounset

verify_args() {
  ## Verifies that the gitbook release is being run for the provided args for
  ## version and commit
  echo "Creating gitbook for version $for_version with commit $commit"
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
    ui_version=$(< VERSION)
    docker_version=$(< VERSION)
    docker_url="release\/wallaroo:$docker_version"
  elif [[ "$BRANCH" == "release" ]]
  then
    remote_branch=release
    ui_version=$(< VERSION)
    docker_version=$(< VERSION)
    docker_url="release\/wallaroo:$docker_version"
  elif [[ "$BRANCH" == *"release-"* ]]
  then
    remote_branch=rc
    ui_version=$(< VERSION)
    docker_version=$(git describe --tags --always)
    docker_url="dev\/wallaroo:$docker_version"
  else
    echo "No remote repo to push book to. Exiting"
    exit 0
  fi
}

update_versions_in_gitbook() {
  echo "Sliding version number into book content with sed magic..."
  version=$(< VERSION)
  echo "Replacing {{ book.wallaroo_version }}"
  find book -name '*.md' -exec sed -i -- "s/{{ book.wallaroo_version }}/$version/g" {} \;
  echo "Replacing {{ metrics_ui_version }}"
  find book -name '*.md' -exec sed -i -- "s/{{ metrics_ui_version }}/$ui_version/g" {} \;
  echo "Replacing {{ docker_version_url }}"
  find book -name '*.md' -exec sed -i -- "s/{{ docker_version_url }}/$docker_url/g" {} \;
}

build_book() {
  echo "Building book..."
  gitbook build
}

upload_book() {
  echo "Uploading book..."
  # gitbook puts generated content in _book
  pushd _book

  # git magic. without all this, our ghp-import command won't work
  git remote add doc-site "git@github.com:wallaroolabs/docs.wallaroolabs.com.git"
  git fetch doc-site
  git reset doc-site/$remote_branch

  mkdir to-upload
  # there's a ton of crap because we build from wallaroo repo root.
  # *everything from the repo* is in this directory. only get the index page,
  # search index, book content and gitbook support css & javascript.
  cp -R index.html search_index.json book gitbook to-upload

  ghp-import -p -r doc-site -b $remote_branch -f to-upload

  popd
}

if [ $# -lt 1 ]; then
  echo "documentation repo token argument required"
fi

set -eu

verify_args
verify_branch
update_versions_in_gitbook
build_book
upload_book
