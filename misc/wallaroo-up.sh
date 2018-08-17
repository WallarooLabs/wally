#!/bin/bash

set -eEuo pipefail

WALLAROO_UP_DEST_DEFAULT=~/wallaroo-tutorial
WALLAROO_UP_DEST_ARG="$WALLAROO_UP_DEST_DEFAULT"
WALLAROO_UP_INSTALL_TYPE=UNSPECIFIED
WALLAROO_VERSION_DEFAULT=release-0.5.2
WALLAROO_VERSION="$WALLAROO_VERSION_DEFAULT"
WALLAROO_TOOLS_TO_BUILD="build-giles-sender-all build-utils-all"

PKGS_TO_INSTALL="git wget findutils"
GOLANG_INSTALL=
PYTHON_INSTALL=

WALLAROO_UP_NAME=wallaroo-up
LOG_FILE="$(pwd -P)/$WALLAROO_UP_NAME.log"

trap "echo \"ERROR!!!! Please check log file ($LOG_FILE) for details.\"" ERR

#reset log file
echo > "$LOG_FILE"
REDIRECT=" >> $LOG_FILE 2>&1"
VERBOSE_REDIRECT=" 2>&1 | tee -a $LOG_FILE"
VERBOSE=

MIN_GOLANG_MAJOR_VERSION=9
GOLANG_VERSION=${GO_VERSION}
GOLANG_DL_URL=https://dl.google.com/go/go${GOLANG_VERSION}.linux-amd64.tar.gz

# sample wallaroo version to ponyc version map entry: W0.4.3=0.21.0
# another sample entry: W4807928=0.22.6
WALLAROO_PONYC_MAP="
Wrelease-0.5.2=0.24.4
Wrelease-0.5.2-81df853=0.24.4
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
#ol-7
fedora-26
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

PREVIEW_COMMANDS=

OS=$(uname -s)

case "$OS" in
    Linux)
    ;;

    *)
    echo "This script has only been tested on Linux. Wallaroo can be "
    echo "installed on non-Linux environments using Docker. Please visit: "
    echo "https://docs.wallaroolabs.com/book/getting-started/docker-setup.html"
    echo "for instructions."
    exit 1
    ;;
esac

run_cmd() {
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

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    if [ "${2:-}" == "root" ]; then
      $root_cmd_pre "$1"
    else
      $cmd_pre "$1"
    fi
  fi
}

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

check_cmd() {
  have_cmd "$1"
  if [[ $? != 0 ]]; then
    error "Needed command '$1' not available"
  fi
}

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

if ! echo "$WALLAROO_PONYC_MAP" | grep "^W$WALLAROO_VERSION=" >/dev/null; then
  usage
  echo
  error "Unsupported Wallaroo version! '$WALLAROO_VERSION'"
else
  PONYC_VERSION=$(echo "$WALLAROO_PONYC_MAP" | grep "^W$WALLAROO_VERSION=" | cut -d'=' -f 2)
  WALLAROO_VERSION_DIRECTORY="wallaroo-${WALLAROO_VERSION}"
fi

WALLAROO_UP_DEST=$(readlink -f "${WALLAROO_UP_DEST_ARG}")

get_distribution() {
  if [ -r /etc/upstream-release/lsb-release ]; then
    dist="$(. /etc/upstream-release/lsb-release && echo "$DISTRIB_ID")"
  elif [ -r /etc/os-release ]; then
    dist="$(. /etc/os-release && echo "$ID")"
  fi

  dist="$(echo "$dist" | tr '[:upper:]' '[:lower:]')"
}

get_distribution_version() {
  if [ -r /etc/upstream-release/lsb-release ]; then
    dist_version="$(. /etc/upstream-release/lsb-release && echo "$DISTRIB_CODENAME")"
  else
    case "$dist" in
      ubuntu)
        if [ -r /etc/lsb-release ]; then
          dist_version="$(. /etc/lsb-release && echo "$DISTRIB_CODENAME")"
        fi
      ;;

      centos)
        if [ -r /etc/os-release ]; then
          dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        fi
      ;;

      rhel|ol)
        if [ -r /etc/os-release ]; then
          dist_version="$(. /etc/os-release && echo "$VERSION_ID" | grep -o '^[0-9]')"
        fi
      ;;

      *)
        if [ -r /etc/os-release ]; then
          dist_version="$(. /etc/os-release && echo "$VERSION_ID")"
        fi
      ;;

    esac
  fi

  dist_version="$(echo "$dist_version" | tr '[:upper:]' '[:lower:]')"
}

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

check_arch() {
  arch=$(uname -m)
  if [ "$arch" != 'x86_64' ]; then
    error "Architecture '${arch}' not supported!"
  fi
}

check_valid_distro() {
  if ! echo "$VALID_DISTRO_VERSIONS" | grep "^$dist-$dist_version\$" >/dev/null; then
    error "Distro/version combination not supported: $dist-$dist_version"
  fi
}

check_golang() {
  GOLANG_UPGRADE=false
  if have_cmd /usr/local/go/bin/go; then
    GOLANG_INSTALLED_MAjOR_VERSION=$( /usr/local/go/bin/go version | grep -o '1\.[0-9]*' | cut -d'.' -f 2 )
    if (( GOLANG_INSTALLED_MAjOR_VERSION < MIN_GOLANG_MAJOR_VERSION )); then
      GOLANG_UPGRADE=true
    else
      GOLANG_INSTALL=false
    fi
  fi
  if have_cmd go; then
    GOLANG_INSTALLED_MAjOR_VERSION=$( go version | grep -o '1\.[0-9]*' | cut -d'.' -f 2 )
    if (( GOLANG_INSTALLED_MAjOR_VERSION < MIN_GOLANG_MAJOR_VERSION )); then
      GOLANG_UPGRADE=true
    else
      GOLANG_INSTALL=false
    fi
  fi
}

install_required_dependencies() {
  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Installing dependencies..."
  fi

  case "$dist" in
    debian|ubuntu)
      if [ "$PYTHON_INSTALL" == "true" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL python-dev"
      fi
      if [ "$PONYC_VERSION" != "" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL ponyc=${PONYC_VERSION}"
      fi
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
      if [ "$PREREQS_TO_INSTALL" != "" ]; then
        run_cmd "apt-get update $REDIRECT" root
        run_cmd "apt-get install -y $PREREQS_TO_INSTALL $REDIRECT" root
      fi
      if ! apt-cache policy 2>&1 | grep pony-language/ponylang-debian > /dev/null 2>&1; then
        run_cmd "apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 'E04F0923 B3B48BDA' $REDIRECT" root
        run_cmd "add-apt-repository 'deb https://dl.bintray.com/pony-language/ponylang-debian ${dist_version} main' $REDIRECT" root
      fi
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL libssl-dev make pony-stable libsnappy-dev liblz4-dev"
      run_cmd "apt-get update $REDIRECT" root
      run_cmd "apt-get install -y $PKGS_TO_INSTALL $REDIRECT" root
    ;;

    centos|rhel|ol)
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL which"
      if [ "$PYTHON_INSTALL" == "true" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL python-devel"
      fi
      if [ "$PONYC_VERSION" != "" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL ponyc-${PONYC_VERSION}"
      fi
      if ! yum list installed -q yum-plugin-copr > /dev/null 2>&1; then
        run_cmd "yum makecache -y $REDIRECT" root
        run_cmd "yum install -y yum-plugin-copr $REDIRECT" root
      fi
      if ! yum repolist 2>&1 | grep ponylang-ponylang > /dev/null 2>&1; then
        run_cmd "yum copr enable ponylang/ponylang epel-7 -y $REDIRECT" root
      fi
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL pony-stable make gcc-c++ snappy-devel openssl-devel lz4-devel"
      run_cmd "yum makecache -y $REDIRECT" root
      run_cmd "yum install -y $PKGS_TO_INSTALL $REDIRECT" root
    ;;

    fedora)
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL which"
      if [ "$PYTHON_INSTALL" == "true" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL python-devel"
      fi
      if [ "$PONYC_VERSION" != "" ]; then
        PKGS_TO_INSTALL="$PKGS_TO_INSTALL ponyc-${PONYC_VERSION}"
      fi
      if ! dnf list installed -q 'dnf-plugins-core' > /dev/null 2>&1; then
        run_cmd "dnf makecache -y >/dev/null $REDIRECT" root
        run_cmd "dnf install 'dnf-command(copr)' -y $REDIRECT" root
      fi
      if ! dnf repolist 2>&1 | grep ponylang-ponylang > /dev/null 2>&1; then
        run_cmd "dnf copr enable ponylang/ponylang -y $REDIRECT" root
      fi
      PKGS_TO_INSTALL="$PKGS_TO_INSTALL pony-stable make gcc-c++ snappy-devel openssl-devel lz4-devel"
      run_cmd "dnf makecache -y $REDIRECT" root
      run_cmd "dnf install -y $PKGS_TO_INSTALL $REDIRECT" root
    ;;

  esac
}

check_wallaroo_dest() {
  BACKUP_WALLAROO_UP_DEST=

  if [ -e "${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}" ]; then
    BACKUP_WALLAROO_UP_DEST=true
  fi
}

configure_wallaroo() {
  if [ "$BACKUP_WALLAROO_UP_DEST" == "true" ]; then
    DATETIME=$(date +%Y%m%d%H%M%S)
    if [ "$PREVIEW_COMMANDS" != "true" ]; then
      log "Backing up existing '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}' to '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}.$DATETIME'..."
    fi
    run_cmd "mv '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}' '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}.$DATETIME' $REDIRECT"
  fi

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Configuring Wallaroo into '${WALLAROO_UP_DEST}/${WALLAROO_VERSION_DIRECTORY}'..."
  fi

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
  run_cmd "wget $QUIET -O $wallaroo_source_archive https://${wallaroo_bintray_subject}.bintray.com/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${WALLAROO_VERSION}/${wallaroo_source_archive} $REDIRECT"
  run_cmd "mkdir ${WALLAROO_VERSION_DIRECTORY} $REDIRECT"
  run_cmd "tar -C ${WALLAROO_VERSION_DIRECTORY} --strip-components=1 -xzf $wallaroo_source_archive $REDIRECT"
  run_cmd "rm $wallaroo_source_archive $REDIRECT"

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    tmp_cmd="echo Running: cd ${WALLAROO_VERSION_DIRECTORY} $REDIRECT"
    eval "$tmp_cmd"
    cd "${WALLAROO_VERSION_DIRECTORY}"
  else
    tmp_cmd="echo cd ${WALLAROO_VERSION_DIRECTORY} $VERBOSE_REDIRECT"
    eval "$tmp_cmd"
  fi

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
    run_cmd "wget $QUIET $GOLANG_DL_URL -O /tmp/go.tar.gz $REDIRECT"
    run_cmd "tar -C bin -xzf /tmp/go.tar.gz $REDIRECT"
    run_cmd "mv bin/go bin/go${GOLANG_VERSION} $REDIRECT"
    run_cmd "rm /tmp/go.tar.gz $REDIRECT"
  fi

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Configuring Wallaroo Metrics UI..."
  fi

  ## download/install monhub appImage
  run_cmd "wget $QUIET -O $metrics_ui_appimage https://${wallaroo_bintray_subject}.bintray.com/${wallaroo_bintray_artifacts_repo}/${wallaroo_bintray_package}/${WALLAROO_VERSION}/${metrics_ui_appimage} $REDIRECT"
  run_cmd "chmod +x $metrics_ui_appimage $REDIRECT"

  # extract the appimage because metrics_ui likes to be able to write to it's directories and also because appimages don't work in docker
  run_cmd "./$metrics_ui_appimage --appimage-extract $REDIRECT"
  run_cmd "mv squashfs-root bin/metrics_ui $REDIRECT"
  run_cmd "sed -i 's/sleep 4/sleep 0/' bin/metrics_ui/AppRun"
  run_cmd "rm $metrics_ui_appimage $REDIRECT"

  if [ "$PREVIEW_COMMANDS" != "true" ]; then
    log "Compiling Wallaroo tools..."
  fi

  run_cmd "make $WALLAROO_TOOLS_TO_BUILD $REDIRECT"

  if [ "$PYTHON_INSTALL" == "true" ]; then
    if [ "$PREVIEW_COMMANDS" != "true" ]; then
      log "Compiling Machida for running Python Wallaroo Applications..."
    fi

    run_cmd "make build-machida-all $REDIRECT"
  fi

  run_cmd "cp utils/data_receiver/data_receiver bin $REDIRECT"
  run_cmd "cp utils/cluster_shutdown/cluster_shutdown bin $REDIRECT"
  run_cmd "cp utils/cluster_shrinker/cluster_shrinker bin $REDIRECT"
  run_cmd "cp giles/sender/sender bin $REDIRECT"
  run_cmd "ln -s metrics_ui/AppRun bin/metrics_reporter_ui $REDIRECT"

  if [ "$PYTHON_INSTALL" == "true" ]; then
    run_cmd "cp machida/build/machida bin $REDIRECT"
    run_cmd "cp machida/wallaroo.py bin $REDIRECT"
  fi

  run_cmd "make clean $REDIRECT $REDIRECT"
}

do_install() {
  install_required_dependencies
  configure_wallaroo
}

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
