#!/bin/bash

set -o errexit
set -o nounset

verify_branch() {
  ## Verifies that this script is being run on the release/release-*
  ## branches only. Sets bintray repo and tag dependent on branch name.
  echo "Verifying that script is being run on a release/release-* branch..."
  BRANCH=$(git rev-parse --abbrev-ref HEAD)
  if [[ $BRANCH == "release" ]]
  then
    # Set version to output of VERSION file
    version=$(< VERSION)
    wallaroo_bintray_artifacts_repo=wallaroolabs-ftp
    bintray_artifacts_version=$version
  elif [[ $BRANCH == *"release-"* ]]
  then
    ## Sets repo to rc for Wallaroo bintray repo
    wallaroo_bintray_artifacts_repo=wallaroolabs-rc
    bintray_artifacts_version=${for_version}
  else
    echo "The bintray release can only be run for the release/release-* branches. You are running this script on the following branch: $BRANCH"
    exit 1
  fi
}

verify_wallaroo_dir() {
  ## Verifies that the script is being run from the wallaroo root directory
  echo "Verifying script is being run from the wallaroo root directory..."
  if [[ "$(basename "$PWD")" != "wallaroo" ]]
  then
    echo "The $0 script must be run from the root wallaroo directory."
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
  if ! git branch --contains "$commit" 2> /dev/null | grep "$BRANCH"
  then
    echo "Commit $commit is not on branch: $BRANCH"
    exit 1
  fi
}

verify_args() {
  ## Verifies that the bintray release is being run for the provided args for
  ## version and commit
  echo "Creating bintray releases for version $for_version with commit $commit"
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
  if ! git diff --exit-code --quiet "$BRANCH" "origin/$BRANCH"
  then
    echo "ERROR! There are local-only changes on branch '$BRANCH'!"
    exit 1
  fi

  if git status --porcelain | grep -E '^.+$' > /dev/null
  then
    echo "ERROR! There are untracked changes!"
    exit 1
  fi
}

checkout_to_commit() {
  echo "Checking out to commit: $commit ..."
  git checkout "$commit"
}

set_artifact_names() {
  ## sets the wallaroo bintray subject
  wallaroo_bintray_subject="wallaroo-labs"
  ## sets the wallaroo bintray package name
  wallaroo_bintray_package="wallaroo"
  ## Sets Wallaroo source archive name
  wallaroo_source_archive="wallaroo-${bintray_artifacts_version}.tar.gz"
  ## Sets Metrics UI appimage name
  metrics_ui_appimage="Wallaroo_Metrics_UI-${bintray_artifacts_version}-x86_64.AppImage"
}

build_metrics_ui_appimage() {
  ## Conditional check for whether the current Metrics UI appimage exists in bintray, does not
  ## re-upload appimage if so. Otherwise uploads to Bintray.
  bintray_metrics_ui_appimage=$(curl -s "https://${wallaroo_bintray_subject}.bintray.com/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${bintray_artifacts_version}/" grep -Po "(?<=>)$metrics_ui_appimage(?=<)" || echo "0")
  if [[ "$bintray_metrics_ui_appimage" == "$metrics_ui_appimage" ]]
  then
    if [[ $BRANCH == "release" ]]
    then
      echo "Appimage for metrics ui: $metrics_ui_appimage already exists in bintray for this release. Cannot overwrite!"
      exit 1
    fi
  fi

  ## delete the existing file if it exists
  rm -f "$metrics_ui_appimage"

  sudo make clean-monitoring_hub

  make build-metrics-ui-appimage

  sudo make clean-monitoring_hub

  mv Wallaroo_Metrics_UI-x86_64.AppImage "$metrics_ui_appimage"
}

build_wallaroo_source_archive() {
  ## Conditional check for whether the current Wallaroo source archive exists in bintray, does not
  ## re-upload archive if so. Otherwise uploads to Bintray.
  bintray_wallaroo_source_archive=$(curl -s "https://${wallaroo_bintray_subject}.bintray.com/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${bintray_artifacts_version}/" grep -Po "(?<=>)$wallaroo_source_archive(?=<)" || echo "0")
  if [[ "$bintray_wallaroo_source_archive" == "$wallaroo_source_archive" ]]
  then
    if [[ $BRANCH == "release" ]]
    then
      echo "Wallaroo source archive: $wallaroo_source_archive already exists in bintray for this release. Cannot overwrite!"
      exit 1
    fi
  fi

  ## delete the existing file if it exists
  rm -f "$wallaroo_source_archive"

  # only include the specific testing data files in use by examples
  rm -r testing
  git checkout -- testing/data/market_spread/nbbo/350-symbols_initial-nbbo-fixish.msg
  git checkout -- testing/data/market_spread/nbbo/350-symbols_nbbo-fixish.msg
  git checkout -- testing/data/market_spread/orders/350-symbols_orders-fixish.msg

  make build-wallaroo-source-archive

  mv wallaroo.tgz "$wallaroo_source_archive"
}

push_wallaroo_bintray_artifacts() {
  ## install jfrog cli if needed
  if [[ ! -x jfrog ]]; then
    curl -fL https://getcli.jfrog.io | sh
  fi

  # push the wallaroo source archive
  if ./jfrog bt u --override --publish "$wallaroo_source_archive" "${wallaroo_bintray_subject}/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${bintray_artifacts_version}" "${wallaroo_bintray_package}/${bintray_artifacts_version}/"
  then
    echo "Uploaded wallaroo source archive $wallaroo_source_archive to bintray successfully."
  else
    echo "Failed to uploaded wallaroo source archive $wallaroo_source_archive to bintray"
  fi

  # push the metrcis appimage
  if ./jfrog bt u --override --publish "$metrics_ui_appimage" "${wallaroo_bintray_subject}/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${bintray_artifacts_version}" "${wallaroo_bintray_package}/${bintray_artifacts_version}/"
  then
    echo "Uploaded $metrics_ui_appimage to bintray successfully."
  else
    echo "Failed to upload $metrics_ui_appimage to bintray."
    exit 1
  fi

  # delete jfrog cli
  rm -f jfrog
}

git_reset() {
  git clean -df
  git reset --hard HEAD
  git checkout "$BRANCH"
}

if [ $# -lt 2 ]; then
  echo "version and commit arguments required"
  exit 1
fi

set -eu
for_version=$1
commit=$2

verify_wallaroo_dir
verify_version
verify_branch
verify_commit_on_branch
verify_args
verify_no_local_changes
checkout_to_commit
set_artifact_names
build_wallaroo_source_archive
build_metrics_ui_appimage
push_wallaroo_bintray_artifacts
git_reset
