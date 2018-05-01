#! /bin/bash

set -o errexit
set -o nounset

verify_branch() {
  ## Verifies that this script is being run on the release/release-*
  ## branches only. Sets docker image repo and tag dependent on branch name.
  echo "Verifying that script is being run on a release/release-* branch..."
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ $BRANCH == "release" ]]
  then
    # Set version to output of VERSION file
    version=$(< VERSION)
    wallaroo_docker_image_repo=release
    docker_image_tag=$version
  elif [[ $BRANCH == *"release-"* ]]
  then
    ## Sets repo to dev for Wallaroo Docker image
    wallaroo_docker_image_repo=dev
    docker_image_tag=$(git describe --tags --always)
  else
    echo "The docker release can only be run for the release/release-* branches. You are running this script on the following branch: $BRANCH"
    exit 1
  fi
}

verify_wallaroo_dir() {
  ## Verifies that the script is being run from the wallaroo root directory
  echo "Verifying script is being run from the wallaroo root directory..."
  if [[ `basename $PWD` != "wallaroo" ]]
  then
    echo "The .docker_release.sh script must be run from the root wallaroo directory."
    exit 1
  fi
}

verify_version() {
  ## Verifies that the provided version matches the version in the VERSION file
  if [[ $(< VERSION) != $for_version ]]; then
    echo "Version provided: $for_version does not match version in VERSION file: $(< VERSION)."
    exit 1
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

verify_args() {
  ## Verifies that the docker release is being run for the provided args for
  ## version and commit
  echo "Creating docker releases for version $for_version with commit $commit"
  while true; do
    read -rp "Is this correct (y/n)?" yn
    case $yn in
    [Yy]*) break;;
    [Nn]*) exit;;
    *) echo "Please answer y or n.";;
    esac
  done
}

verify_no_local_changes() {
  if ! git diff --exit-code $BRANCH origin/$BRANCH
  then
    echo "ERROR! There are local-only changes on branch '$BRANCH'!"
    exit 1
  fi
}

checkout_to_commit() {
  echo "Checking out to commit: $commit ..."
  git checkout $commit
}

set_docker_image_names() {
  ## Sets Wallaroo Docker repo host to Bintray repo
  wallaroo_docker_repo_host=wallaroo-labs-docker-wallaroolabs.bintray.io
  ## Sets Wallaroo Docker image name, tag and path
  wallaroo_docker_image=wallaroo:$docker_image_tag
  wallaroo_docker_image_path=$wallaroo_docker_repo_host/$wallaroo_docker_image_repo/$wallaroo_docker_image
  ## Sets Metrics UI Docker image name, tag, and path
  metrics_ui_docker_image=metrics_ui:$docker_image_tag
  metrics_ui_docker_image_path=$wallaroo_docker_repo_host/$wallaroo_docker_image_repo/$metrics_ui_docker_image
}

build_metrics_ui_image() {
  ## Check to see if image exists prior to building
  if [[ "$(docker images -q $metrics_ui_docker_image_path 2> /dev/null)" == "" ]]; then
    ## Build Metrics UI if not already built
    make release-monitoring_hub-apps-metrics_reporter_ui
    ## Build Metrics UI Docker image
    make arch=amd64 build-docker-monitoring_hub-apps-metrics_reporter_ui
    ## Tag Metrics UI docker image for release
    git_tag=$(git describe --tags --always)
    docker tag wallaroolabs/monitoring_hub-apps-metrics_reporter_ui.amd64:$git_tag $metrics_ui_docker_image_path
  else
    echo "Docker image: $metrics_ui_docker_image_path already exists locally, skipping build step..."
  fi
}

build_wallaroo_image() {
  ## Check to see if image exists prior to building
  if [[ "$(docker images -q $wallaroo_docker_image_path 2> /dev/null)" == "" ]]; then
    ## Build Metrics UI if not already built
    make release-monitoring_hub-apps-metrics_reporter_ui
    ## Build Wallaroo Docker image
    docker build -t $wallaroo_docker_image_path .
  else
    echo "Docker image: $wallaroo_docker_image_path already exists locally, skipping build step..."
  fi
}

push_docker_images() {
  ## Conditional check for whether the current Wallaroo image tag exists in repo, does not
  ## re-upload image if so. Otherwise uploads to Bintray.
  returned_tag_name=$(curl -s "https://$wallaroo_docker_repo_host/v2/$wallaroo_docker_image_repo/wallaroo/tags/list" | jq ".tags" | grep -Po "(?<=\")$docker_image_tag(?=\")" || echo "0")
  if [[ "$returned_tag_name" == "$docker_image_tag" ]]
  then
    echo "Docker image: $wallaroo_docker_image_path already exists."
  else
    # push the image
    if $(docker push $wallaroo_docker_image_path)
    then
      echo "Pushed image $wallaroo_docker_image_path successfully."
    else
      echo "Failed to push image: $wallaroo_docker_image_path"
    fi
  fi

  ## Conditional check for whether the current Metrics UI image tag exists in repo, does not
  ## re-upload image if so. Otherwise uploads to Bintray.
  returned_tag_name=$(curl -s "https://$wallaroo_docker_repo_host/v2/$wallaroo_docker_image_repo/metrics_ui/tags/list" | jq ".tags" | grep -Po "(?<=\")$docker_image_tag(?=\")" || echo "0")
  if [[ "$returned_tag_name" == "$docker_image_tag" ]]
  then
    echo "Docker image: $metrics_ui_docker_image_path already exists."
  else
    # push the image
    if $(docker push $metrics_ui_docker_image_path)
    then
      echo "Pushed image $metrics_ui_docker_image_path successfully."
    else
      echo "Failed to push image $metrics_ui_docker_image_path"
      exit 1
    fi
  fi
}

if [ $# -lt 2 ]; then
  echo "version and commit arguments required"
fi

set -eu
for_version=$1
commit=$2

verify_args
verify_wallaroo_dir
verify_version
verify_branch
verify_commit_on_branch
checkout_to_commit
verify_no_local_changes
set_docker_image_names
build_metrics_ui_image
build_wallaroo_image
push_docker_images
