#! /bin/bash

set -o errexit
set -o nounset

# determine remote branch to use
if [[ "$TRAVIS_BRANCH" == "master" ]]
then
  remote_branch=master
  ui_version=$(< VERSION)
  docker_version=$(< VERSION)
  docker_url="release/wallaroo:$docker_version"
elif [[ "$TRAVIS_BRANCH" == "release" ]]
then
  remote_branch=release
  ui_version=$(< VERSION)
  docker_version=$(< VERSION)
  docker_url="release/wallaroo:$docker_version"
elif [[ "$TRAVIS_BRANCH" == *"release-"* ]]
then
  remote_branch=rc
  # TODO: automation
  ui_version="0.3.3"
  docker_version=$(git describe --tags --always)
  docker_url="dev/wallaroo:$docker_version"
else
  echo "No remote repo to push book to. Exiting"
  exit 0
fi

echo "Sliding version number into book content with sed magic..."
version=$(< VERSION)
find book -name '*.md' -exec sed -i -- "s/{{ book.wallaroo_version }}/$version/g" {} \;
find book -name '*.md' -exec sed -i -- "s/{{ metrics_ui_version }}/$ui_version/g" {} \;
find book -name '*.md' -exec sed -i -- "s/{{ docker_version_url }}/$docker_url/g" {} \;

echo "Building book..."
gitbook build

echo "Uploading book..."
# gitbook puts generated content in _book
pushd _book

# git magic. without all this, our ghp-import command won't work
git remote add doc-site "https://${DOCUMENTATION_REPO_TOKEN}@github.com/wallaroolabs/docs.wallaroolabs.com"
git fetch doc-site
git reset doc-site/$remote_branch

mkdir to-upload
# there's a ton of crap because we build from wallaroo repo root.
# *everything from the repo* is in this directory. only get the index page,
# search index, book content and gitbook support css & javascript.
cp -R index.html search_index.json book gitbook to-upload

ghp-import -p -r doc-site -b $remote_branch -f to-upload

popd
