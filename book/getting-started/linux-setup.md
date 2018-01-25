# Setting Up Your Ubuntu Environment for Wallaroo

These instructions have been tested for Ubuntu Trusty and Xenial releases.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Memory requirements

In order to compile the Wallaroo example applications, your system will need to have approximately 6 GB working memory (this can be RAM or swap). If you don't have enough memory, you are likely to see that the compile process is `Killed` by the OS.

## Update apt-get

Ensures you'll have the latest available packages:

```bash
sudo apt-get update
```

## Installing git

If you do not already have Git installed, install it:

```bash
sudo apt-get install git
```

## Install make

```bash
sudo apt-get update
sudo apt-get install -y build-essential
```

## Install libssl-dev

```bash
sudo apt-get install -y libssl-dev
```

### Install GCC 4.7 or Higher

 If you have at least GCC 4.7 installed on your machine, you don't need to do anything. If you have gcc 4.6 or lower, you'll need to upgrade. You can check your `gcc` version by running:

```bash
gcc --version
```

To upgrade to GCC 5 if you don't have at least GCC 4.7:

```bash
sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
```

then

```bash
sudo apt-get update
sudo apt-get install -y gcc-5 g++-5
```

And set `gcc-5` as the default option:

```bash
sudo update-alternatives --install /usr/bin/gcc gcc \
  /usr/bin/gcc-5 60 --slave /usr/bin/g++ g++ /usr/bin/g++-5
```

## Add ponyc and pony-stable apt-key keyserver

In order to install `ponyc` and `pony-stable` via `apt-get` the following keyserver must be added to the APT key management utility.

```bash
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "D401AB61 DBE1D0A2"
```

### Installing ponyc

Now you need to install Pony compiler `ponyc`. Run:

```bash
echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get -V install ponyc=0.21.0-4301.acd811b
```

## Installing pony-stable

Next, you need to install `pony-stable`, a Pony dependency management library. Navigate to a directory where you will put the `pony-stable` repo and execute the following commands:

```bash
echo "deb https://dl.bintray.com/pony-language/pony-stable-debian /" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get -V install pony-stable
```

## Install Compression Development Libraries

Wallaroo's Kakfa support requires `libsnappy` and `liblz` to be installed.

### Xenial Ubuntu:

```bash
sudo apt-get install -y libsnappy-dev liblz4-dev
```

### Trusty Ubuntu:

Install libsnappy:

```bash
sudo apt-get install -y libsnappy-dev
```

Trusty Ubuntu has an outdated `liblz4` package. You will need to install from source like this:

```bash
cd ~/
wget -O liblz4-1.7.5.tar.gz https://github.com/lz4/lz4/archive/v1.7.5.tar.gz
tar zxvf liblz4-1.7.5.tar.gz
cd lz4-1.7.5
make
sudo make install
```

## Install Python Development Libraries

```bash
sudo apt-get install -y python-dev
```

## Install Docker

You'll need Docker (CE or EE) to run the Wallaroo metrics UI. There are [instructions](https://docs.docker.com/engine/installation/linux/ubuntu/) for getting Docker up and running on Ubuntu on the [Docker website](https://docs.docker.com/engine/installation/linux/ubuntu/).

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/engine/installation/linux/linux-postinstall/#configure-docker-to-start-on-boot).

All of the Docker commands throughout the rest of this manual assume that you have permission to run Docker commands as a non-root user. Follow the [Manage Docker as a non-root user](https://docs.docker.com/engine/installation/linux/linux-postinstall/#manage-docker-as-a-non-root-user) instructions to set that up. If you don't want to allow a non-root user to run Docker commands, you'll need to run `sudo docker` anywhere you see `docker` for a command.

## Download the Metrics UI

```bash
sudo docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:{{ metrics_ui_version }}
```

## Set up Environment for the Wallaroo Tutorial

If you haven't already done so, create a directory called `~/wallaroo-tutorial` and navigate there by running:

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. If you haven't already cloned the Wallaroo repo, do so now (this will create a subdirectory called `wallaroo`):

```bash
git clone https://github.com/WallarooLabs/wallaroo
cd wallaroo
git checkout {{ book.wallaroo_version }}
```

## Compiling Machida

Machida is the program that runs Wallaroo Python applications. Change to the `machida` directory:

```bash
cd ~/wallaroo-tutorial/wallaroo/machida
make
```

## Compiling Giles Sender, Receiver, Cluster Shutdown, and Cluster Shrinker tools

Giles Sender is used to supply data to Wallaroo applications over TCP, and Giles Receiver is used as a fast TCP Sink that writes the messages it receives to a file, along with a timestmap. The two together are useful when developing and testing applications that use TCP Sources and a TCP Sink.

The Cluster Shutdown tool is used to instruct the cluster to shutdown cleanly, clearing away any resilience and recovery files it may have created.

The Cluster Shrinker tool is used to tell a running cluster to reduce the number of workers in the cluster and to query the cluster for information about how many workers are eligible for removal.

To compile all three, run

```bash
cd ~/wallaroo-tutorial/wallaroo/
make build-utils-all
```

## Register

Register today and receive a Wallaroo T-shirt and a one-hour phone consultation with Sean, our V.P. of Engineering, to discuss your streaming data questions. Not sure if you have a streaming data problem? Not sure how to go about architecting a streaming data system? Looking to improve an existing system? Not sure how Wallaroo can help? Sean has extensive experience and is happy to help you work through your questions.

Please register here: [https://www.wallaroolabs.com/register](https://www.wallaroolabs.com/register).

Your email address will only be used to facilitate the above.

## Conclusion

Awesome! All set. Time to try running your first application.
