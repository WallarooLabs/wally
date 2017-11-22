#! /bin/bash

set -o errexit
set -o nounset

download_llvm() {
  echo "Downloading and installing the LLVM specified by envvars..."

  wget "http://llvm.org/releases/${LLVM_VERSION}/clang+llvm-${LLVM_VERSION}-x86_64-linux-gnu-debian8.tar.xz"
  tar -xvf clang+llvm*
  pushd clang+llvm* && sudo mkdir /tmp/llvm && sudo cp -r ./* /tmp/llvm/
  sudo ln -s "/tmp/llvm/bin/llvm-config" "/usr/local/bin/${LLVM_CONFIG}"
  popd
}

download_pcre() {
  echo "Downloading and building PCRE2..."

  wget "ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2"
  tar -xjvf pcre2-10.21.tar.bz2
  pushd pcre2-10.21 && ./configure --prefix=/usr && make && sudo make install
  popd
}

install_cpuset() {
  # if cpuset isn't installed, we get warning messages that dirty up
  # the travis output logs
  sudo apt-get -fy install cpuset
}

install_ponyc() {
  echo "Installing ponyc"
  if [[ "$INSTALL_PONYC_FROM" == "last-release" ]]
  then
    echo "Installing latest ponyc release from bintray"
    sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "8756 C4F7 65C9 AC3C B6B8  5D62 379C E192 D401 AB61"
    echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list
    sudo apt-get update
    sudo apt-get -V install ponyc
  fi
}

install_pony_stable() {
  echo "Installing latest pony-stable release from bintray"
  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2"
  echo "deb https://dl.bintray.com/pony-language/pony-stable-debian /" | sudo tee -a /etc/apt/sources.list
  sudo apt-get update
  sudo apt-get -V install pony-stable
}

install_kafka_compression_libraries() {
  echo "Installing compression libraries needed for Kafka support"
  sudo apt-get install libsnappy-dev
  pushd /tmp
  wget -O liblz4-1.7.5.tar.gz https://github.com/lz4/lz4/archive/v1.7.5.tar.gz
  tar zxvf liblz4-1.7.5.tar.gz
  pushd lz4-1.7.5
  sudo make install
  popd
  popd
}

install_monitoring_hub_dependencies() {
  echo "Installing monitoring hub dependencies"
  #echo "Installing kerl"
  #pushd /tmp
  #wget https://raw.githubusercontent.com/kerl/kerl/master/kerl
  #chmod a+x kerl
  #/tmp/kerl build 18.3 18.3
  #/tmp/kerl install 18.3 /tmp/erlang
  #. /tmp/erlang/activate
  #export PATH="/tmp/erlang/bin:$PATH"
  echo "deb https://packages.erlang-solutions.com/ubuntu trusty contrib" | sudo tee -a /etc/apt/sources.list
  pushd /tmp
  wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
  sudo apt-key add erlang_solutions.asc
  popd
  sudo apt-get update
  #sudo apt-get -fy install erlang=1:18.3
  sudo apt-get -fy install erlang-base=1:18.0 erlang-dev=1:18.0 \
    erlang-parsetools=1:18.0 erlang-eunit=1:18.0 erlang-crypto=1:18.0 \
    erlang-syntax-tools=1:18.0 erlang-asn1=1:18.0 erlang-public-key=1:18.0 \
    erlang-ssl=1:18.0 erlang-mnesia=1:18.0 erlang-runtime-tools=1:18.0 \
    erlang-inets=1:18.0
  kiex install 1.2.6
  kiex default 1.2.6
  source $HOME/.kiex/elixirs/elixir-1.2.6.env
  mix local.hex --force
  mix local.rebar --force
}

install_python_dependencies() {
  echo "Installing python dependencies"
  echo "Installing pytest"
  sudo python2 -m pip install pytest==3.2.2
  echo "Install enum"
  sudo python2 -m pip install --upgrade pip enum34
}

install_cpuset
install_ponyc
install_pony_stable
install_kafka_compression_libraries
install_monitoring_hub_dependencies
install_python_dependencies
