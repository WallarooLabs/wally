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
    docker_metrics_ui_url="release\/metrics_ui:$ui_version"
    bintray_repo_url="https://wallaroo-labs.bintray.com/wallaroolabs-ftp"
  elif [[ "$BRANCH" == "release" ]]
  then
    remote_branch=release
    ui_version=$(< VERSION)
    docker_version=$(< VERSION)
    docker_url="release\/wallaroo:$docker_version"
    docker_metrics_ui_url="release\/metrics_ui:$ui_version"
    bintray_repo_url="https://wallaroo-labs.bintray.com/wallaroolabs-ftp"
  elif [[ "$BRANCH" == *"release-"* ]]
  then
    remote_branch=rc
    ui_version=$(git describe --tags --always)
    docker_version=$(git describe --tags --always)
    docker_url="dev\/wallaroo:$docker_version"
    docker_metrics_ui_url="dev\/metrics_ui:$ui_version"
    bintray_repo_url="https://wallaroo-labs.bintray.com/wallaroolabs-rc"
  else
    echo "No remote repo to push book to. Exiting"
    exit 0
  fi
}

verify_commit_on_branch() {
  echo "Verfying commit $commit is on branch: $BRANCH..."
  if ! git branch --contains $commit | grep $BRANCH
  then
    echo "Commit $commit is not on branch: $BRANCH"
    exit 1
  fi
}

checkout_to_commit() {

  git checkout $commit
}

update_versions_in_gitbook() {
  echo "Sliding version number into book content with sed magic..."
  version=$(< VERSION)
  echo "Replacing {{ book.wallaroo_version }}"
  find book -name '*.md' -exec sed -i -- "s@{{ book.wallaroo_version }}@$version@g" {} \;
  find -name 'intro.md' -exec sed -i -- "s@{{ book.wallaroo_version }}@$version@g" {} \;
  echo "Replacing {{ docker_metrics_ui_url }}"
  find book -name '*.md' -exec sed -i -- "s@{{ docker_metrics_ui_url }}@$docker_metrics_ui_url@g" {} \;
  echo "Replacing {{ docker_version_url }}"
  find book -name '*.md' -exec sed -i -- "s@{{ docker_version_url }}@$docker_url@g" {} \;
  echo "Replacing {{ book.bintray_repo_url }}"
  find book -name '*.md' -exec sed -i -- "s@{{ book.bintray_repo_url }}@$bintray_repo_url@g" {} \;
  GO_VERSION=$(grep -Po '(?<=GO_VERSION=").*(?=")' .release/bootstrap.sh)
  echo "Replacing {{ book.golang_version }}"
  find book -name '*.md' -exec sed -i -- "s@{{ book.golang_version }}@$GO_VERSION@g" {} \;
}

install_gitbook_deps() {
  echo "Installing Gitbook deps..."
  gitbook install
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

git_clean() {
  echo "Cleaning repo..."
  git clean -fd
  git remote rm doc-site
  echo "Checking out to $BRANCH"
  git reset --hard origin/$BRANCH
  git checkout $BRANCH
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
update_versions_in_gitbook
install_gitbook_deps
build_book
upload_book
git_clean
