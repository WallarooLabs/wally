#! /bin/bash

set -o errexit
set -o nounset
export DEBIAN_FRONTEND=noninteractive

export PONYC_VERSION="0.21.0-4301.acd811b"
export OTP_VERSION="1:20.1-1"
export ELIXIR_VERSION="1.5.2-1"
export GO_VERSION="1.9.4"


install_ponyc() {
  echo "** Installing latest ponyc ${PONYC_VERSION} from bintray"

  sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "8756 C4F7 65C9 AC3C B6B8  5D62 379C E192 D401 AB61"
  echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list.d/pony-language.list
  sudo apt-get update

  sudo apt-get -V install ponyc=$PONYC_VERSION

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

install_required_libraries() {
  echo "** Installing additional libraries required for Wallaroo support"
  sudo apt-get install -y libz-dev libssl-dev
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

  mkdir /home/vagrant/.nvm
  curl -o- https://raw.githubusercontent.com/creationix/nvm/v0.33.11/install.sh | NVM_DIR="/home/vagrant/.nvm" PROFILE="vagrant" bash
  NVM_DIR="/home/vagrant/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
  nvm install node
  nvm alias default node

  echo "** Monitoring hub dependencies installed"
}

install_python_dependencies() {
  echo "** Installing python dependencies"
  echo "Installing python"
  sudo apt-get install -y python-dev
  echo "Installing build-essential"
  sudo apt-get install -y build-essential
  echo "Installing pip"
  sudo apt-get install -y python-pip
  echo "Installing pytest"
  sudo -H python -m pip install pytest==3.2.2
  echo "Install enum"
  sudo -H python -m pip install --upgrade pip enum34

  echo "** Python dependencies installed"
}

install_gitbook_dependencies() {
  # install gitbook
  npm install gitbook-cli -g
  # install any required plugins - this checks book.json for plugin list
  gitbook install
  # for uploading generated docs to repo
  sudo -H python -m pip install ghp-import
}

install_docker() {
  ## docker ce repo setup
  sudo apt-get update
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    software-properties-common

  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

  sudo add-apt-repository \
     "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
     $(lsb_release -cs) \
     stable"

  sudo apt-get update
  sudo apt-get install -y docker-ce

  ## give docker access to non-root users vagrant
  sudo usermod -aG docker vagrant
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

install_changelog_tool() {
  git clone https://github.com/ponylang/changelog-tool
  cd changelog-tool
  make
  sudo make install
}

install_other() {
  echo "** Installing other required tooling..."
  sudo apt-get install -y jq
}


confirm_git_ssh() {
  echo "** Confirming ssh connection to git...."
  ssh -T git@github.com -o StrictHostKeyChecking=no || true
  echo "** Git SSH successful!"
}

clone_and_report() {
  echo "** Cloning Wallaroo repo"
  git clone git@github.com:WallarooLabs/wallaroo.git
  curl -v -H "Accept: application/json" \
        -H "Content-Type: application/json" \
        -X POST \
        -d "{\"date\":\"$(date)\",\"source\":\"vagrant\",\"count\":1}" \
        https://hooks.zapier.com/hooks/catch/175929/f4hnh4/

  echo "** Wallaroo repo cloned"
}

echo "----- Installing dependencies"

install_ponyc
install_pony_stable
install_kafka_compression_libraries
install_required_libraries
install_monitoring_hub_dependencies
install_python_dependencies
install_gitbook_dependencies
install_docker
install_go
install_other
install_changelog_tool

echo "----- Dependencies installed"

## confirming git ssh
confirm_git_ssh

## clone Wallaroo
pushd /home/vagrant
clone_and_report
pushd wallaroo || exit
