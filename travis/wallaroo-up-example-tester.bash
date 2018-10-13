#!/bin/bash

set -eEuo pipefail

# ping chuck's clone tracking endpoint
wget -S --header="Accept: application/json" --header="Content-Type: application/json" --post-data="{\"date\":\"$(date)\",\"source\":\"travis-ci\",\"count\":1}" -O - https://hooks.zapier.com/hooks/catch/175929/f4hnh4/

# define realpath if it doesn't exist
command -v realpath >/dev/null 2>&1 || realpath() {
  cd "$1"; pwd -P
}

# figure out wallaroo directory, script directory and set testing temp relative to it
HERE="$(realpath "$(dirname "${0}")")"
WALLAROO_DIR="$(realpath "${HERE}/..")"
TESTING_TMP="${HERE}/logs/wallaroo-release-tester"

sudo apt-get update
sudo apt-get install -y curl
sudo apt-get remove -y libpcre3-dev

# we're testing custom artifacts then build them
CUSTOM_MESSAGE="with custom artifacts"
pushd "${WALLAROO_DIR}"
CUSTOM_WALLAROO_SOURCE_TGZ_URL="${WALLAROO_DIR}/wallaroo.tgz"
CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL="${WALLAROO_DIR}/Wallaroo_Metrics_UI-x86_64.AppImage"
if [[ ! -e "${CUSTOM_WALLAROO_SOURCE_TGZ_URL}" ]]; then
  echo "Building wallaroo source archive for testing using custom artifacts..."
  make build-wallaroo-source-archive
fi
if [[ ! -e "${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL}" ]]; then
  echo "Building wallaroo metrics ui appimage for testing using custom artifacts..."
  make build-metrics-ui-appimage
fi

export CUSTOM_WALLAROO_SOURCE_TGZ_URL=${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-}
export CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL=${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-}
mkdir -p "${TESTING_TMP}"
cd "${TESTING_TMP}"
echo "Running Wallaroo Up..."
echo y | ${WALLAROO_DIR}/misc/wallaroo-up.sh -t python || (cat /home/travis/build/WallarooLabs/wallaroo/travis/logs/wallaroo-release-tester/wallaroo-up.log && exit 1)
export TMPDIR="${TESTING_TMP}"
echo "Running example tester..."
export VERBOSE_ERROR=true
bash ~/wallaroo-tutorial/wallaroo*/misc/example-tester.bash $1
