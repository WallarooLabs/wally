#! /bin/bash

set -o errexit
set -o nounset
export DEBIAN_FRONTEND=noninteractive

export WALLAROO_VERSION="release-0.4.2"
export PONYC_VERSION="0.21.3"
export OTP_VERSION="1:20.1-1"
export ELIXIR_VERSION="1.5.2-1"
export GO_VERSION="1.9.4"


install_ponyc() {
  echo "** Installing ponyc $PONYC_VERSION"
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
	sudo apt-get install -y libz-dev libssl-dev
}

install_monitoring_hub_dependencies() {
  echo "** Installing Monitoring Hub dependencies"

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
  echo "Install enum"
  sudo -H python -m pip install --upgrade pip enum34

  echo "** Python dependencies installed"
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

clone_and_build_wallaroo() {
	pushd /home/vagrant
	mkdir wallaroo-tutorial
	pushd wallaroo-tutorial || exit

	git clone https://github.com/WallarooLabs/wallaroo
	pushd wallaroo || exit
	git checkout $WALLAROO_VERSION

	## build and release monitoring hub
	make build-monitoring_hub-apps-metrics_reporter_ui release-monitoring_hub-apps-metrics_reporter_ui

	## build machida and wallaroo utils
	make build-machida build-giles-all build-utils-all
}

add_metrics_ui_to_path() {
	sudo mkdir /usr/local/metrics_reporter_ui
	chown -R vagrant:vagrant /usr/local/metrics_reporter_ui
	mv /home/vagrant/wallaroo-tutorial/wallaroo/monitoring_hub/apps/metrics_reporter_ui/_build/prod/rel/metrics_reporter_ui/releases/0.0.1/metrics_reporter_ui.tar.gz /tmp/metrics_reporter_ui.tar.gz
	tar -xvf /tmp/metrics_reporter_ui.tar.gz -C /usr/local/metrics_reporter_ui

	echo "PATH=/usr/local/metrics_reporter_ui/bin:$PATH" >> /home/vagrant/.bashrc
}


echo "----- Installing dependencies"

install_ponyc
install_pony_stable
install_kafka_compression_libraries
install_required_libraries
install_monitoring_hub_dependencies
install_python_dependencies
install_go

echo "----- Dependencies installed"

## clone and build Wallaroo
clone_and_build_wallaroo

## add Metrics UI to PATH
add_metrics_ui_to_path

## allow vagrant user access to everything
pushd /home/vagrant
chown -R vagrant:vagrant wallaroo-tutorial
