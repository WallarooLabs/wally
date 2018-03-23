#!/bin/bash

wallaroo_version="0c02e661"
## setup our various additional source

## pony bintray repo setup
apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2"
echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list
echo "deb https://dl.bintray.com/pony-language/pony-stable-debian /" | sudo tee -a /etc/apt/sources.list

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

## install our dependencies

apt-get update
apt-get install -y build-essential \
  docker-ce \
  git \
  liblz4-dev \
  libsnappy-dev \
  libssl-dev \
  make \
  pony-stable \
  ponyc=0.21.0-4301.acd811b \
  python-dev

## switch to default vagrant user
su - vagrant

## clone Wallaroo and build various Wallaroo tools
pushd /home/vagrant
mkdir wallaroo-tutorial
pushd wallaroo-tutorial || exit

git clone https://github.com/WallarooLabs/wallaroo
pushd wallaroo || exit
git checkout $wallaroo_version

pushd machida || exit
make
popd

make build-giles-all build-utils-all

## allow vagrant user access to everything
pushd /home/vagrant
chown -R vagrant:vagrant wallaroo-tutorial
