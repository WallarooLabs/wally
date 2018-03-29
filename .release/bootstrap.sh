#! /bin/bash

set -o errexit
set -o nounset
export DEBIAN_FRONTEND=noninteractive

export INSTALL_PONYC_FROM="bintray"
export LLVM_VERSION="3.9.1"
export LLVM_CONFIG="llvm-config-3.9"
export CC1="gcc-5"
export CXX="g++-5"
export OTP_VERSION="1:20.1-1"
export ELIXIR_VERSION="1.5.2-1"
export GO_VERSION="1.9.4"

install_llvm() {
  echo "** Downloading and installing LLVM ${LLVM_VERSION}"

  pushd /tmp
  wget "http://llvm.org/releases/${LLVM_VERSION}/clang+llvm-${LLVM_VERSION}-x86_64-linux-gnu-debian8.tar.xz"
  tar -xf clang+llvm*
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
  tar -xjf pcre2-10.21.tar.bz2
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
      echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list.d/pony-language.list
      sudo apt-get update

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
  echo "deb https://dl.bintray.com/pony-language/pony-stable-debian /" | sudo tee -a /etc/apt/sources.list.d/pony-stable-debian.list
  sudo apt-get update
  sudo apt-get -V -y install pony-stable

  echo "** pony-stable installed"
}

install_kafka_compression_libraries() {
  echo "** Installing compression libraries needed for Kafka support"

  sudo apt-get install -y libsnappy-dev liblz4-dev

  echo "** Compression libraries needed for Kafka support installed"
}

install_monitoring_hub_dependencies() {
  echo "** Installing monitoring hub dependencies"

  echo "deb https://packages.erlang-solutions.com/ubuntu trusty contrib" | sudo tee -a /etc/apt/sources.list.d/erlang-solutions.list
  pushd /tmp
  wget https://packages.erlang-solutions.com/ubuntu/erlang_solutions.asc
  sudo apt-key add erlang_solutions.asc
  popd
  sudo apt-get update
  sudo apt-get -fy install erlang-base=$OTP_VERSION erlang-dev=$OTP_VERSION \
    erlang-parsetools=$OTP_VERSION erlang-eunit=$OTP_VERSION erlang-crypto=$OTP_VERSION \
    erlang-syntax-tools=$OTP_VERSION erlang-asn1=$OTP_VERSION erlang-public-key=$OTP_VERSION \
    erlang-ssl=$OTP_VERSION erlang-mnesia=$OTP_VERSION erlang-runtime-tools=$OTP_VERSION \
    erlang-inets=$OTP_VERSION elixir=$ELIXIR_VERSION

  echo "** Monitoring hub dependencies installed"
}

install_python_dependencies() {
  echo "** Installing python dependencies"
  echo "Installing python"
  apt-get install -y python-dev
  echo "Installing build-essential"
  apt-get install -y build-essential
  echo "Installing pip"
  apt-get install -y python-pip
  echo "Installing pytest"
  sudo python -m pip install pytest==3.2.2
  echo "Install enum"
  sudo python -m pip install --upgrade pip enum34

  echo "** Python dependencies installed"
}

install_gitbook_dependencies() {
  # we need nodejs & npm
  sudo apt-get update
  sudo apt-get install -y nodejs npm
  # we need to symlink node
  ln -s /usr/bin/nodejs /usr/bin/node
  # install gitbook
  npm install gitbook-cli -g
  # install any required plugins - this checks book.json for plugin list
  gitbook install
  # for uploading generated docs to repo
  sudo python -m pip install ghp-import
}

install_docker() {
  ## docker ce repo setup
  apt-get update
  apt-get install \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -

  add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

  apt-get update
  apt-get install -y docker-ce

  ## give docker access to non-root users ubuntu
  sudo usermod -aG docker ubuntu
  newgrp docker
}

install_go() {
  echo "** Downloading and installing Go ${GO_VERSION}"

  pushd /tmp
  wget "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz"
  tar -xf go*
  pushd go* && sudo mkdir /usr/local/go && sudo cp -r ./* /usr/local/go/
  echo "PATH=$PATH:/usr/local/go/bin" | sudo tee -a /etc/profile.d/go-path.sh
  popd
  popd

  echo "** Go ${GO_VERSION} installed"
}

echo "----- Installing dependencies"

install_cpuset
install_ponyc
install_pony_stable
install_kafka_compression_libraries
install_monitoring_hub_dependencies
install_python_dependencies
install_gitbook_dependencies
install_docker
install_go

echo "----- Dependencies installed"

## switch to default ubuntu user
su - ubuntu

## clone Wallaroo
pushd /home/ubuntu
git clone https://github.com/WallarooLabs/wallaroo
pushd wallaroo || exit

## allow ubuntu user access to everything
pushd /home/ubuntu
chown -R ubuntu:ubuntu wallaroo
