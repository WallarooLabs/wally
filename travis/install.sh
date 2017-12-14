#! /bin/bash

set -o errexit
set -o nounset

install_llvm() {
  echo "** Downloading and installing LLVM ${LLVM_VERSION}"

  pushd /tmp
  wget "http://llvm.org/releases/${LLVM_VERSION}/clang+llvm-${LLVM_VERSION}-x86_64-linux-gnu-debian8.tar.xz"
  tar -xvf clang+llvm*
  pushd clang+llvm* && sudo mkdir /tmp/llvm && sudo cp -r ./* /tmp/llvm/
  sudo ln -s "/tmp/llvm/bin/llvm-config" "/usr/local/bin/${LLVM_CONFIG}"
  popd
  popd

  echo "** LLVM ${LLVM_VERSION} installed"
}

install_pcre() {
  echo "** Downloading and building PCRE2..."

  pushd /tmp
  wget "ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2"
  tar -xjvf pcre2-10.21.tar.bz2
  pushd pcre2-10.21 && ./configure --prefix=/usr && make && sudo make install
  popd
  popd

  echo "** PRCE2 installed"
}

install_cpuset() {
  # if cpuset isn't installed, we get warning messages that dirty up
  # the travis output logs
  echo "** Installing cpuset"

  sudo apt-get -fy install cpuset

  echo "** cpuset installed"
}

install_ponyc() {
  echo "** Installing ponyc from ${INSTALL_PONYC_FROM}"

  case "$INSTALL_PONYC_FROM" in
    "bintray")
      echo "Installing latest ponyc release from bintray"
      sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "8756 C4F7 65C9 AC3C B6B8  5D62 379C E192 D401 AB61"
      echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list
      sudo apt-get update
      # this temporarily doesn't work.
      #sudo apt-get -V install ponyc=$PONYC_VERSION
      # temporarily install latest until ponyc as sane version numbers
      sudo apt-get -V install ponyc
    ;;

    "source")
      echo "Installing ponyc dependencies"
      install_llvm
      install_pcre
      echo "Installing ponyc from source"
      pushd /tmp
      git clone https://github.com/ponylang/ponyc.git
      pushd ponyc
      git checkout $PONYC_VERSION
      make CC=$CC1 CXX=$CXX1
      sudo make install
      popd
      popd
    ;;

    *)
      echo "ERROR: unrecognized source to install ponyc from ${INSTALL_PONYC_FROM}"
      exit 1
    ;;
  esac

  echo "** ponyc installed"
}

install_pony_stable() {
  echo "** Installing pony-stable"

  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2"
  echo "deb https://dl.bintray.com/pony-language/pony-stable-debian /" | sudo tee -a /etc/apt/sources.list
  sudo apt-get update
  sudo apt-get -V install pony-stable

  echo "** pony-stable installed"
}

install_kafka_compression_libraries() {
  echo "** Installing compression libraries needed for Kafka support"

  sudo apt-get install libsnappy-dev
  pushd /tmp
  wget -O liblz4-1.7.5.tar.gz https://github.com/lz4/lz4/archive/v1.7.5.tar.gz
  tar zxvf liblz4-1.7.5.tar.gz
  pushd lz4-1.7.5
  sudo make install
  popd
  popd

  echo "** Compression libraries needed for Kafka support installed"
}

install_monitoring_hub_dependencies() {
  echo "** Installing monitoring hub dependencies"

  echo "deb https://packages.erlang-solutions.com/ubuntu trusty contrib" | sudo tee -a /etc/apt/sources.list
  pushd /tmp
  wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
  sudo apt-key add erlang_solutions.asc
  popd
  sudo apt-get update
  sudo apt-get -fy install erlang-base=1:18.0 erlang-dev=1:18.0 \
    erlang-parsetools=1:18.0 erlang-eunit=1:18.0 erlang-crypto=1:18.0 \
    erlang-syntax-tools=1:18.0 erlang-asn1=1:18.0 erlang-public-key=1:18.0 \
    erlang-ssl=1:18.0 erlang-mnesia=1:18.0 erlang-runtime-tools=1:18.0 \
    erlang-inets=1:18.0
  echo "Install keix and setup Elixir version"
  kiex install 1.2.6
  kiex default 1.2.6

  echo "** Monitoring hub dependencies installed"
}

install_python_dependencies() {
  echo "** Installing python dependencies"

  echo "Installing pytest"
  sudo python2 -m pip install pytest==3.2.2
  echo "Install enum"
  sudo python2 -m pip install --upgrade pip enum34

  echo "** Python dependencies installed"
}

turn_off_o_noblock() {
  echo "PRINTING O_NONBLOCK flag"
  echo `python -c 'import os,sys,fcntl; flags = fcntl.fcntl(sys.stdout, fcntl.F_GETFL); print(flags&os.O_NONBLOCK);'`
  python -c 'import os,sys,fcntl; flags = fcntl.fcntl(sys.stdout, fcntl.F_GETFL); fcntl.fcntl(sys.stdout, fcntl.F_SETFL, flags&~os.O_NONBLOCK);'
  echo "PRINTING O_NONBLOCK flag"
  echo `python -c 'import os,sys,fcntl; flags = fcntl.fcntl(sys.stdout, fcntl.F_GETFL); print(flags&os.O_NONBLOCK);'`
}

echo "----- Installing dependencies"

turn_off_o_noblock
install_cpuset
install_ponyc
install_pony_stable
install_kafka_compression_libraries
install_monitoring_hub_dependencies
install_python_dependencies

echo "----- Dependencies installed"
