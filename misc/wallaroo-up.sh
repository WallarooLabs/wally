#!/bin/bash

# md5 for validatiing script checksum
MD5="d404135a72affc910c29a7680fa043ba  -"

set -eEuo pipefail

WALLAROO_UP_DEST_DEFAULT=~/wallaroo-tutorial
WALLAROO_UP_DEST_ARG="$WALLAROO_UP_DEST_DEFAULT"
WALLAROO_UP_INSTALL_TYPE=UNSPECIFIED
WALLAROO_VERSION_DEFAULT=0.5.4
WALLAROO_VERSION="$WALLAROO_VERSION_DEFAULT"
WALLAROO_TOOLS_TO_BUILD="build-giles-sender-all build-utils-all"

PKGS_TO_INSTALL="git wget findutils"
GOLANG_INSTALL=
PYTHON_INSTALL=

WALLAROO_UP_NAME=wallaroo-up
LOG_FILE="$(pwd -P)/$WALLAROO_UP_NAME.log"

set_trap() {
  trap 'echo "ERROR!!!! Please check log file ($LOG_FILE) for details."' ERR
}

clear_trap() {
  trap - ERR
}

# set trap
set_trap

#reset log file
echo > "$LOG_FILE"

# set up redirects
REDIRECT=" >> $LOG_FILE 2>&1"
VERBOSE_REDIRECT=" 2>&1 | tee -a $LOG_FILE"
VERBOSE=

GOLANG_VERSION=1.9.4
GOLANG_DL_URL=https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz

# sample wallaroo version to ponyc version map entry: W0.4.3=0.21.0
# another sample entry: W4807928=0.22.6
WALLAROO_PONYC_MAP="
W0.5.4=0.25.0
W0.5.3=0.24.4
W0.5.2=0.24.4
Wuse-ponyc-0.25=0.25.0
Wmaster=
"

VALID_INSTALL_TYPES="
all
golang
python
"

VALID_DISTRO_VERSIONS="
centos-7
rhel-7
ol-7
amzn-2
fedora-27
fedora-28
ubuntu-trusty
ubuntu-xenial
ubuntu-artful
ubuntu-bionic
debian-jessie
debian-stretch
debian-buster
"

VALID_DISTRO_VERSIONS_PYTHON3="
ubuntu-xenial
ubuntu-artful
ubuntu-bionic
debian-stretch
debian-buster
"

PREVIEW_COMMANDS=

OS=$(uname -s)

# check OS
case "$OS" in
    Linux)
    ;;

    *)
    echo "This script has only been tested on Linux. Wallaroo can be "
    echo "installed on non-Linux environments using Docker or Vagrant. Please visit: "
    echo "https://docs.wallaroolabs.com/book/getting-started/choosing-an-installation-option.html"
    echo "for instructions for a Python Wallaroo environment or please visit: "
    echo "https://docs.wallaroolabs.com/book/go/getting-started/choosing-an-installation-option.html"
    echo "for instructions for a Go Wallaroo environment."
    exit 1
    ;;
esac

# check checksum of script to ensure it wasn't accidentally mangled
CALCULATED_MD5="$(tail -n +5 "$0" | md5sum)"
if [[ "$CALCULATED_MD5" != "$MD5" ]]; then
  echo "Checksum error in '$0'! Script is corrupted! Please re-download." >&2
  exit 1
fi

# function to log/run command (or if preview, only log it)
run_cmd() {
  num_retries=0
  max_retries=0

  # only retry if requested
  if [ "${3:-}" == "retry" ]; then
    max_retries=3
  fi

  # retry loop
  while true; do

    # log commnd being run
    if [ "${2:-}" == "root" ]; then
      if [ "$PREVIEW_COMMANDS" == "true" ]; then
        tmp_cmd="echo \"$root_cmd_pre '$1'\" $VERBOSE_REDIRECT"
      else
        tmp_cmd="echo \"Running: $root_cmd_pre '$1'\" $REDIRECT"
      fi
    else
      if [ "$PREVIEW_COMMANDS" == "true" ]; then
        tmp_cmd="echo \"$cmd_pre '$1'\" $VERBOSE_REDIRECT"
      else
        tmp_cmd="echo \"Running: $cmd_pre '$1'\" $REDIRECT"
      fi
    fi
    eval "$tmp_cmd"

    # if not previewing, run the command
    if [ "$PREVIEW_COMMANDS" != "true" ]; then
      # disable exit on error and trap
      set +e
      clear_trap

      # run command (as root or normal)
      if [ "${2:-}" == "root" ]; then
        $root_cmd_pre "$1"
      else
        $cmd_pre "$1"
      fi

      # check exit code from command
      # shellcheck disable=SC2181
      if [ $? -eq 0 ]; then
        break
      fi

      # check if we've exhausted all of our retries
      (( num_retries=num_retries+1 ))
      if [ $num_retries -gt $max_retries ]; then
        if [ "${2:-}" == "root" ]; then
          echo "ERROR! Error running '$root_cmd_pre \"$1\"'!"
        else
          echo "ERROR! Error running '$cmd_pre \"$1\"'!"
        fi
        echo "ERROR!!!! Please check log file ($LOG_FILE) for details."
        exit 1
      fi

      # sleep for 1 second before retrying again
      sleep 1
      # re-enable exit on error and trap
      set_trap
      set -e
    else
      break
    fi
  done
}

# function to log messages
log() {
  tmp_cmd="echo \"$WALLAROO_UP_NAME: $1\" $REDIRECT"
  eval "$tmp_cmd"
  if [ "$VERBOSE" != "true" ]; then
    echo "$WALLAROO_UP_NAME: $1"
  fi
}

error() {
    log "ERROR: $1" >&2
    exit 1
}

# function to check if a command exists or exit with failure otherwise
check_cmd() {
  if have_cmd "$1"; then
    error "Needed command '$1' not available"
  fi
}

# check if a command exists
have_cmd() {
  command -v "$1" > /dev/null 2>&1
}

usage() {
    cat 1>&2 <<EOF
The installer for a wallaroo development environment

USAGE:
    $WALLAROO_UP_NAME [FLAGS] [OPTIONS]

FLAGS:
    -h            Prints help information
    -v            Verbose output

OPTIONS:
    -t <type>     Choose a wallaroo install type (all/golang/python)
    -p <path>     Where to put wallaroo code (DEFAULT: $WALLAROO_UP_DEST_DEFAULT)
    -w <version>  Wallaroo version to install (DEFAULT: $WALLAROO_VERSION_DEFAULT)
EOF
}

# parse command line options
while getopts 'vht:p:w:' OPTION; do
  case "$OPTION" in
    t)
      WALLAROO_UP_INSTALL_TYPE="$(echo "$OPTARG" | tr '[:upper:]' '[:lower:]')"
      ;;

    h)
      usage
      exit 1
      ;;

    p)
      WALLAROO_UP_DEST_ARG="$OPTARG"
      ;;

    w)
      WALLAROO_VERSION="$OPTARG"
      ;;

    v)
      REDIRECT="$VERBOSE_REDIRECT"
      VERBOSE=true
      ;;

    ?)
      usage
      exit 1
      ;;

  esac
done
shift "$((OPTIND -1))"

# validate arguments and set variables
if ! echo "$VALID_INSTALL_TYPES" | grep "^$WALLAROO_UP_INSTALL_TYPE\$" >/dev/null; then
  usage
  echo
  error "Invalid install type! '$WALLAROO_UP_INSTALL_TYPE'"
else
  case "$WALLAROO_UP_INSTALL_TYPE" in
    python)
      PYTHON_INSTALL="true"
    ;;

    golang)
      GOLANG_INSTALL="true"
    ;;

    all)
      PYTHON_INSTALL="true"
      GOLANG_INSTALL="true"
    ;;
  esac
fi

# validate wallaroo version requested
if ! echo "$WALLAROO_PONYC_MAP" | grep "^W$WALLAROO_VERSION=" >/dev/null; then
  usage
  echo
  error "Unsupported Wallaroo version! '$WALLAROO_VERSION'"
else
  PONYC_VERSION=$(echo "$WALLAROO_PONYC_MAP" | grep "^W$WALLAROO_VERSION=" | cut -d'=' -f 2)
  WALLAROO_VERSION_DIRECTORY="wallaroo-${WALLAROO_VERSION}"
fi

WALLAROO_UP_DEST=$(readlink -m "${WALLAROO_UP_DEST_ARG}")

# get which distribution we're running on
get_distribution() {
  # check upstream lsb-release info if it exists
  if [ -r /etc/upstream-release/lsb-release ]; then
    # shellcheck disable=SC1091
    dist="$(. /etc/upstream-release/lsb-release && echo "$DISTRIB_ID")"
  # otherwise use standard os-release info
  elif [ -r /etc/os-release ]; then
    # shellcheck disable=SC1091
    dist="$(. /etc/os-release && echo "$ID")"
  fi

  # make it all lowercase just in case
  # shellcheck disable=SC1091
  dist="$(echo "$dist" | tr '[:upper:]' '[:lower:]')"
}

# get version of distribution
get_distribution_version() {
  # check upstream lsb-release info if it exists
  if [ -r /etc/upstream-release/lsb-release ]; then
    # shellcheck disable=SC1091
    dist_version="$(. /etc/upstream-release/lsb-release && echo "$DISTRIB_CODENAME")"
  else
    # otherwise use standard stuff based on distribution
    case "$dist" in
      ubuntu)
        if [ -r /etc/lsb-release ]; then
          # shellcheck disable=SC1091
          dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
        fi
      ;;

      centos)
        if [ -r /etc/os-release ]; then
          # shellcheck disable=SC1091
          dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        fi
      ;;

      rhel|ol)
        if [ -r /etc/os-release ]; then
          # for RHEL/OL we need to get the major version out of a version number that looks like 7.5
          # shellcheck disable=SC1091
          dist_version="$(. /etc/os-release && echo "$VERSION_ID" | grep -o '^[0-9]')"
        fi
      ;;

      debian)
        if [ -r /etc/os-release ]; then
          # for debian, os-release is a number and not the codename and for testing there is no VERSION_ID set so we fall back to reading parsing it from debian_version
          # shellcheck disable=SC1091
          dist_version="$(. /etc/os-release && echo "${VERSION_ID:-$(cut -d'/' -f1 < /etc/debian_version)}")"
          case "$dist_version" in
            10)
              dist_version="buster"
            ;;
            9)
              dist_version="stretch"
            ;;
            8)
              dist_version="jessie"
            ;;
          esac
        fi
      ;;

      *)
        if [ -r /etc/os-release ]; then
          # shellcheck disable=SC1091
          dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        fi
      ;;

    esac
  fi

  dist_version="$(echo "$dist_version" | tr '[:upper:]' '[:lower:]')"
}

# Figure out if we have sudo or not or if we're already root for when running commands
set_cmd_prefix() {
  root_cmd_pre="sh -c"
  cmd_pre="sh -c"
  HAVE_ROOT=rootuser
  if [ "$(whoami)" != 'root' ]; then
    if have_cmd sudo; then
      root_cmd_pre='sudo sh -c'
      HAVE_ROOT=sudo
    else
      HAVE_ROOT=
    fi
  fi
}

# check architecture
check_arch() {
  arch=$(uname -m)
  if [ "$arch" != 'x86_64' ]; then
    error "Wallaroo is currently only available for x86_64 architectures. Architecture '${arch}' not supported!"
  fi
}

# confirm we're running for a distro/version combination we support
check_valid_distro() {
  if ! echo "$VALID_DISTRO_VERSIONS" | grep "^$dist-$dist_version\$" >/dev/null; then
    error "Distro/version combination not supported: $dist-$dist_version"
  fi
}

# install dependencies for wallaroo
install_required_dependencies() {
  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Installing dependencies..."
  fi

  case "$dist" in
    debian|ubuntu)
      # figure out which pre-reqs need installing and install them
      PREREQS_TO_INSTALL=
      if ! dpkg -l | grep -q '\Wsoftware-properties-common\W'; then
        PREREQS_TO_INSTALL="$PREREQS_TO_INSTALL software-properties-common"
      fi
      if ! dpkg -l | grep -q '\Wapt-transport-https\W'; then
        PREREQS_TO_INSTALL="$PREREQS_TO_INSTALL apt-transport-https"
      fi
      if ! dpkg -l | grep -q '\Wca-certificates\W'; then
        PREREQS_TO_INSTALL="$PREREQS_TO_INSTALL ca-certificates"
      fi
      if ! dpkg -l | grep -q '\Wcurl\W'; then
        PREREQS_TO_INSTALL="$PREREQS_TO_INSTALL curl"
      fi
      if ! dpkg -l | grep -q '\Wgnupg2\W'; then
        PREREQS_TO_INSTALL="$PREREQS_TO_INSTALL gnupg2"
      fi
      if ! dpkg -l | grep -q '\Wdirmngr\W'; then
        PREREQS_TO_INSTALL="$PREREQS_TO_INSTALL dirmngr"
      fi
      if [ "$PREREQS_TO_INSTALL" != "" ]; then
        run_cmd "apt-get update $REDIRECT" root retry
        run_cmd "apt-get install -y $PREREQS_TO_INSTALL $REDIRECT" root retry
      fi

      # figure out which packages need installing
      if [ "$PYTHON_INSTALL" == "true" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL python-dev"
        if echo "$VALID_DISTRO_VERSIONS_PYTHON3" | grep "^$dist-$dist_version\$" >/dev/null; then
          PKGS_TO_INSTALL="$PKGS_TO_INSTALL python3-dev"
        fi
      fi
      if [ "$PONYC_VERSION" != "" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL ponyc=${PONYC_VERSION}"
      fi
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL libssl-dev make pony-stable libsnappy-dev liblz4-dev"

      # if jessie/trusty add in wallaroolabs-debian repo for backport of liblz4 needed by Wallaroo
      case "$dist_version" in
        jessie|trusty)
          if ! apt-cache policy 2>&1 | grep wallaroolabs-debian > /dev/null 2>&1; then
            run_cmd "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys 379CE192D401AB61 $REDIRECT" root retry
            run_cmd "add-apt-repository 'deb https://wallaroo-labs.bintray.com/wallaroolabs-debian ${dist_version} main' $REDIRECT" root
          fi
        ;;
      esac

      # add in ponylang-debian repo for ponylang install
      if ! apt-cache policy 2>&1 | grep pony-language/ponylang-debian > /dev/null 2>&1; then
        run_cmd "apt-key adv --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys E04F0923 B3B48BDA $REDIRECT" root retry
        run_cmd "add-apt-repository 'deb https://dl.bintray.com/pony-language/ponylang-debian ${dist_version} main' $REDIRECT" root
      fi

      # install dependencies for wallaroo
      run_cmd "apt-get update $REDIRECT" root retry
      run_cmd "apt-get install -y $PKGS_TO_INSTALL $REDIRECT" root retry
    ;;

    centos|rhel|ol|amzn)
      # figure out which packages need installing
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL which"
      if [ "$PYTHON_INSTALL" == "true" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL python-devel"
      fi
      if [ "$PONYC_VERSION" != "" ]; then
        PKGS_TO_INSTALL="ponyc-${PONYC_VERSION} $PKGS_TO_INSTALL"
      fi
      if [ "$dist" == "amzn" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL tar"
      fi
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL pony-stable make gcc-c++ snappy-devel openssl-devel lz4-devel"

      # if oracle linux, enable the optional repo
      if [ "$dist" == "ol" ]; then
        run_cmd "yum-config-manager --enable ol7_optional_latest $REDIRECT" root
      fi

      # enable ponylang copr repo
      if ! yum list installed -q yum-plugin-copr > /dev/null 2>&1; then
        run_cmd "yum makecache -y $REDIRECT" root retry
        run_cmd "yum install -y yum-plugin-copr $REDIRECT" root retry
      fi
      if ! yum repolist 2>&1 | grep ponylang-ponylang > /dev/null 2>&1; then
        run_cmd "yum copr enable ponylang/ponylang epel-7 -y $REDIRECT" root
      fi
      run_cmd "yum makecache -y $REDIRECT" root retry

      ## install one at a time or else yum doesn't throw an error for missing packages
      for pkg in $PKGS_TO_INSTALL; do
        run_cmd "yum install -y $pkg $REDIRECT" root retry
      done
    ;;

    fedora)
      # figure out which packages need installing
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL which"
      if [ "$PYTHON_INSTALL" == "true" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL python-devel"
      fi
      if [ "$PONYC_VERSION" != "" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL ponyc-${PONYC_VERSION}"
      fi
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL pony-stable make gcc-c++ snappy-devel openssl-devel lz4-devel"

      # enable ponylang copr repo
      if ! dnf list installed -q 'dnf-plugins-core' > /dev/null 2>&1; then
        run_cmd "dnf makecache -y >/dev/null $REDIRECT" root retry
        run_cmd "dnf install 'dnf-command(copr)' -y $REDIRECT" root retry
      fi
      if ! dnf repolist 2>&1 | grep ponylang-ponylang > /dev/null 2>&1; then
        run_cmd "dnf copr enable ponylang/ponylang -y $REDIRECT" root
      fi
      run_cmd "dnf makecache -y $REDIRECT" root retry

      # install dependencies for wallaroo
      run_cmd "dnf install -y $PKGS_TO_INSTALL $REDIRECT" root retry
    ;;

    *)
      echo "ERROR! Unknown distribution: $dist with version $dist_version"
      exit 1
    ;;

  esac
}

# check to see if the wallaroo destination already exists
check_wallaroo_dest() {
  BACKUP_WALLAROO_UP_DEST=

  if [ -e "${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}" ]; then
    BACKUP_WALLAROO_UP_DEST=true
  fi
}

# configure wallaroo version being installed
configure_wallaroo() {
  # back up wallaroo directory if needed
  if [ "$BACKUP_WALLAROO_UP_DEST" == "true" ]; then
    INSTALL_TYPE=subsequent
    DATETIME=$(date +%Y%m%d%H%M%S)
    if [ "$PREVIEW_COMMANDS" != "true" ]; then
      log "Backing up existing '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}' to '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}.$DATETIME'..."
    fi
    run_cmd "mv '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}' '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}.$DATETIME' $REDIRECT"
  fi

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Configuring Wallaroo into '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}'..."
  fi

  # make wallaroo destination directory and change to it
  run_cmd "mkdir -p \"$WALLAROO_UP_DEST\" $REDIRECT"

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    tmp_cmd="echo Running: cd $WALLAROO_UP_DEST $REDIRECT"
    eval "$tmp_cmd"
    cd "$WALLAROO_UP_DEST"
  else
    tmp_cmd="echo cd $WALLAROO_UP_DEST $VERBOSE_REDIRECT"
    eval "$tmp_cmd"
  fi

  ## sets the wallaroo bintray subject
  wallaroo_bintray_subject="wallaroo-labs"
  ## sets the wallaroo bintray package name
  wallaroo_bintray_package="wallaroo"
  ## Sets Wallaroo source archive name
  wallaroo_source_archive="wallaroo-${WALLAROO_VERSION}.tar.gz"
  ## Sets Metrics UI appimage name
  metrics_ui_appimage="Wallaroo_Metrics_UI-${WALLAROO_VERSION}-x86_64.AppImage"

  # set the correct wallaroo bintray repo name
  if [[ "$WALLAROO_VERSION" == "release"* ]]; then
    wallaroo_bintray_artifacts_repo=wallaroolabs-rc
  else
    wallaroo_bintray_artifacts_repo=wallaroolabs-ftp
  fi

  QUIET=-q
  if [ "$VERBOSE" == "true" ]; then
    QUIET=
  fi

  ## download/untar wallaroo release tgz from bintray
  WGET_URL_SUFFIX="?source=${WALLAROO_UP_SOURCE:-wallaroo-up}&install=${INSTALL_TYPE:-initial}&install_type=${WALLAROO_UP_INSTALL_TYPE}"
  WGET_URL_SUFFIX=
  WALLAROO_SOURCE_TGZ_URL="https://${wallaroo_bintray_subject}.bintray.com/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${WALLAROO_VERSION}/${wallaroo_source_archive}${WGET_URL_SUFFIX}"

  # download wallaroo source code (use custom tgz if requested for testing)
  if [[ "${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-}" == "" ]]; then
    run_cmd "wget $QUIET -O $wallaroo_source_archive '${WALLAROO_SOURCE_TGZ_URL}' $REDIRECT" "" retry
  else
    log "Using custom wallaroo source tgz '${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-}'..."
    if [[ "${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-}" == "http://"* ]] ; then
      run_cmd "wget $QUIET -O $wallaroo_source_archive '${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-}' $REDIRECT" "" retry
    else
      run_cmd "cp ${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-} $wallaroo_source_archive $REDIRECT"
    fi
  fi

  # make wallaroo version directory and extract wallaroo source code into it
  run_cmd "mkdir ${WALLAROO_VERSION_DIRECTORY} $REDIRECT"
  run_cmd "tar -C ${WALLAROO_VERSION_DIRECTORY} --strip-components=1 -xzf $wallaroo_source_archive $REDIRECT"
  run_cmd "rm $wallaroo_source_archive $REDIRECT"

  # change to wallaroo version directory
  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    tmp_cmd="echo Running: cd ${WALLAROO_VERSION_DIRECTORY} $REDIRECT"
    eval "$tmp_cmd"
    cd "${WALLAROO_VERSION_DIRECTORY}"

    # do a make clean if using a custom wallaroo source tgz
    if [[ "${CUSTOM_WALLAROO_SOURCE_TGZ_URL:-}" != "" ]]; then
      run_cmd "make clean $REDIRECT"
    fi
  else
    tmp_cmd="echo cd ${WALLAROO_VERSION_DIRECTORY} $VERBOSE_REDIRECT"
    eval "$tmp_cmd"
  fi

  # make bin directory
  run_cmd "mkdir bin $REDIRECT"

  ## download/install our private golang
  if [ "$GOLANG_INSTALL" == "true" ]; then
    if [ "$PREVIEW_COMMANDS" != "true" ]; then
      log "Downloading and configuring private golang version $GOLANG_VERSION..."
    fi

    QUIET=-q
    if [ "$VERBOSE" == "true" ]; then
      QUIET=
    fi
    run_cmd "wget $QUIET $GOLANG_DL_URL -O /tmp/go.tar.gz $REDIRECT" "" retry
    run_cmd "tar -C bin -xzf /tmp/go.tar.gz $REDIRECT"
    run_cmd "mv bin/go bin/go${GOLANG_VERSION} $REDIRECT"
    run_cmd "rm /tmp/go.tar.gz $REDIRECT"
  fi

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Configuring Wallaroo Metrics UI..."
  fi

  ## download/install metrics UI appImage
  WALLAROO_METRICS_UI_APPIMAGE_URL="https://${wallaroo_bintray_subject}.bintray.com/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${WALLAROO_VERSION}/${metrics_ui_appimage}${WGET_URL_SUFFIX}"
  if [[ "${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-}" == "" ]]; then
    run_cmd "wget $QUIET -O $metrics_ui_appimage '${WALLAROO_METRICS_UI_APPIMAGE_URL}' $REDIRECT" "" retry
  else
    log "Using custom wallaroo metrics ui appimage '${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-}'..."
    if [[ "${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-}" == "http://"* ]] ; then
      run_cmd "wget $QUIET -O $metrics_ui_appimage '${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-}' $REDIRECT" "" retry
    else
      run_cmd "cp ${CUSTOM_WALLAROO_METRICS_UI_APPIMAGE_URL:-} $metrics_ui_appimage $REDIRECT"
    fi
  fi
  run_cmd "chmod +x $metrics_ui_appimage $REDIRECT"

  # extract the appimage because metrics_ui likes to be able to write to it's directories and also because appimages don't work in docker
  run_cmd "./$metrics_ui_appimage --appimage-extract $REDIRECT"
  run_cmd "mv squashfs-root bin/metrics_ui $REDIRECT"

  # delete libtinfo.so.5 so the one provided by the distribution can be used
  if [[ "$dist" != "fedora" ]]; then
    if [[ "$dist_version" != "buster" ]]; then
      run_cmd "rm bin/metrics_ui/usr/lib/libtinfo.so.5"
    fi
  fi
  run_cmd "sed -i 's/sleep 4/sleep 0/' bin/metrics_ui/AppRun"
  run_cmd "rm $metrics_ui_appimage $REDIRECT"

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Compiling Wallaroo tools..."
  fi

  # compile wallaroo tools
  run_cmd "make ${CUSTOM_WALLAROO_BUILD_ARGS:-} $WALLAROO_TOOLS_TO_BUILD $REDIRECT"

  # compile machida if needed
  if [ "$PYTHON_INSTALL" == "true" ]; then
    if [ "$PREVIEW_COMMANDS" != "true" ]; then
      log "Compiling Machida for running Python Wallaroo Applications..."
    fi

    echo "building machida with resilience"
    run_cmd "make ${CUSTOM_WALLAROO_BUILD_ARGS:-} build-machida-all resilience=on $REDIRECT"
    run_cmd "mv machida/build/machida bin/machida-resilience $REDIRECT"
    echo "building machida without resilience"
    run_cmd "make ${CUSTOM_WALLAROO_BUILD_ARGS:-} build-machida-all $REDIRECT"
    run_cmd "cp machida/build/machida bin $REDIRECT"
    run_cmd "cp -r machida/lib bin/pylib $REDIRECT"

    if echo "$VALID_DISTRO_VERSIONS_PYTHON3" | grep "^$dist-$dist_version\$" >/dev/null; then
      echo "building machida3 with resilience"
      run_cmd "make ${CUSTOM_WALLAROO_BUILD_ARGS:-} build-machida3-all resilience=on $REDIRECT"
      run_cmd "mv machida3/build/machida3 bin/machida3-resilience $REDIRECT"
      echo "building machida3 without resilience"
      run_cmd "make ${CUSTOM_WALLAROO_BUILD_ARGS:-} build-machida3-all $REDIRECT"
      run_cmd "cp machida3/build/machida3 bin $REDIRECT"
    fi
  fi

  # copy binaries to the bin directory
  run_cmd "cp utils/data_receiver/data_receiver bin $REDIRECT"
  run_cmd "cp utils/cluster_shutdown/cluster_shutdown bin $REDIRECT"
  run_cmd "cp utils/cluster_shrinker/cluster_shrinker bin $REDIRECT"
  run_cmd "cp giles/sender/sender bin $REDIRECT"
  run_cmd "ln -s metrics_ui/AppRun bin/metrics_reporter_ui $REDIRECT"

  # clean up built artifacts
  run_cmd "make clean $REDIRECT $REDIRECT"
}

# do the actual install
do_install() {
  install_required_dependencies
  configure_wallaroo
}

# get user permission prior to proceeding
user_permission() {
  log "This script will install/configure Wallaroo version '$WALLAROO_VERSION' for $dist-$dist_version."
  log "It will use root privileges via '$HAVE_ROOT' to perform administrative tasks."
  log ""
  log "It will perform the following actions:"
  log ""
  log "* Add the ponylang repo to the package manager (if necessary)"
  log "* Install the Wallaroo dependencies including ponyc and required libraries"
  if [ "$PYTHON_INSTALL" == "true" ]; then
    log "* Install the python development libraries for python support for Wallaroo"
  fi
  if [ "$GOLANG_INSTALL" == "true" ]; then
    log "* Install private golang for golang support for Wallaroo"
  fi
  if [ "$BACKUP_WALLAROO_UP_DEST" == "true" ]; then
    log "* Back up the existing '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}'"
  fi
  log "* Get the Wallaroo source code and put it into '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}'"
  log "* Compile Wallaroo related tools (sender, cluster_shutdown, etc)"
  log ""
  log "NOTE: Full log of all actions can be found in $LOG_FILE"
  log ""

  if [ "$HAVE_ROOT" == "" ]; then
    log "Error: this installer needs the ability to run commands as root."
    error 'Unable to find "sudo" available to make this happen. Cannot proceed!'
  fi

  # allow user to proceed/abort/preview
  while true; do
    read -rp "$WALLAROO_UP_NAME: Ok to proceed with installation (y = Yes, n = No, p = preview)? " yn
    case $yn in
    [Yy]*)
      log "Proceeding with installation"
      break
      ;;

    [Nn]*)
      log "Aborting installation!"
      exit
      ;;

    [Pp]*)
      log ""
      log "Commands to run:"
      PREVIEW_COMMANDS=true
      echo
      do_install
      echo
      PREVIEW_COMMANDS=false
      log ""
      ;;

    *)
      log "Please answer y, n or p."
      ;;
    esac
  done

}

# put the activate script in the right location
create_env_file() {
  cd "${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}"
  cp misc/activate bin/

  log "Please use \"source bin/activate\" in '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}' to set up environment for wallaroo."
}

main() {
  check_arch
  get_distribution
  get_distribution_version
  check_valid_distro
  set_cmd_prefix
  check_wallaroo_dest
  user_permission

  do_install

  create_env_file

  log ""
  log "Successfully configured Wallaroo into '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}'!"
}

main
