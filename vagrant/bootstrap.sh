#! /bin/bash

set -o errexit
set -o nounset

export WALLAROO_VERSION="0.5.2"

wallaroo_up() {
  cd /tmp
  curl https://raw.githubusercontent.com/WallarooLabs/wallaroo/${WALLAROO_VERSION}/misc/wallaroo-up.sh -o wallaroo-up.sh -J -L
  chmod +x wallaroo-up.sh
  export WALLAROO_UP_SOURCE=vagrant
  echo y | ./wallaroo-up.sh -t all
}

add_activate_to_bashrc() {
  echo "source /home/vagrant/wallaroo-tutorial/wallaroo-${WALLAROO_VERSION}/bin/activate" >> /home/vagrant/.bashrc
}

## clone and build Wallaroo
wallaroo_up

## add Metrics UI to PATH
add_activate_to_bashrc

## allow vagrant user access to everything
pushd /home/vagrant
chown -R vagrant:vagrant wallaroo-tutorial
