#! /bin/bash

set -o errexit
set -o nounset

# determine remote branch to use
if [[ "$TRAVIS_BRANCH" == "master" ]]
then
  remote_branch=master
elif [[ "$TRAVIS_BRANCH" == "release" ]]
then
  remote_branch=release
elif [[ "$TRAVIS_BRANCH" == *"release-"* ]]
then
  remote_branch=rc
else
  echo "No remote repo to push book to. Exiting"
  exit 0
fi

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
