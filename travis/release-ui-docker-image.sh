#! /bin/bash
set -x
set -o errexit
set -o nounset

if [[ "$TRAVIS_BRANCH" == "release" ]]
then
  echo "On release branch. Skipping UI docker image creation."
  echo "Automated builds for release aren't supported yet."
  exit 0
elif [[ "$TRAVIS_BRANCH" == *"release-"* ]]
then
  # defined in a TravisCI "repository setting"
  password=$DOCKERHUB_PASSWORD
  echo "Logging in to Dockerhub"
  docker login -u wallaroolabs -p $password
else
  exit 0
end

echo "Building Metrics UI docker image..."
make arch=amd64 build-docker-monitoring_hub-apps-metrics_reporter_ui
# after make succeeds, we have a tagged image
