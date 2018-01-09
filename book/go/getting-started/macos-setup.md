# Setting Up Your MacOS Environment for Wallaroo

These instructions have been tested on OSX El Capitan and MacOS Sierra.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Install Go

You'll need a Go 1.9.x compiler. You can get one from the [Go website](https://golang.org/doc/install).

## Installing Xcode Command Line Tools

If you do not already have Xcode installed, you can run the following in a terminal window:

```bash
xcode-select --install
```

You can then click “Install” to download and install Xcode Command Line Tools.

## Installing a Package Manager, Homebrew

Homebrew is used for easy installation of certain packages needed by Pony.

Instructions for installing Homebrew can be found [on their website](http://brew.sh/).  This book assumes that you use the default installation directory, `/usr/local`.  If you choose an alternate installation directory, please configure your shell's `PATH` environment variable as needed.

**NOTE:** For users of the MacPorts package manager, we strongly recommend *not* using MacPorts.  It is extremely difficult to correctly install the compiler toolchain required by Wallaroo using only MacPorts.

## Installing git

If you do not already have Git installed, install it via Homebrew:

```bash
brew install git
```

## Installing the Pony Compiler

### Installing ponyc

Now you need to install the Pony compiler `ponyc`.

```bash
brew update
brew install ponyc
```

## Installing pony-stable

Next, you need to install `pony-stable`, a Pony dependency management library:

```bash
brew update
brew install pony-stable
```

## Install Compression Development Libraries

Wallaroo's Kafka support requires a `libsnappy` and `liblz` to be installed.

```bash
brew install snappy lz4
```

## Install Docker

You'll need Docker to run the Wallaroo metrics UI. There are [instructions](https://docs.docker.com/docker-for-mac/) for getting Docker up and running on MacOS on the [Docker website](https://docs.docker.com/docker-for-mac/).  We recommend the 'Standard' version of the 'Docker for Mac' package.

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/docker-for-mac/#general).

## Download the Metrics UI

```bash
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:0.3.3
```

## Set up Environment for the Wallaroo Tutorial

If you haven't already done so, create a directory called `~/wallaroo-tutorial` and navigate there by running:

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. If you haven't already
cloned the Wallaroo repo, do so now:

```bash
git clone https://github.com/WallarooLabs/wallaroo
cd wallaroo
git checkout 0.3.3
```

This will create a subdirectory called `wallaroo`.

## Compiling Giles Sender, Data Receiver, and the Cluster Shutdown tool

Giles Sender is used to supply data to Wallaroo applications over TCP, and Data Receiver is used as a fast TCP Sink that can write the messages it receives to STDOUT. The two together are useful when developing and testing applications that use TCP Sources and a TCP Sink.

The Cluster Shutdown tool is used to instruct the cluster to shutdown cleanly, clearing away any resilience and recovery files it may have created.

To compile all three, run

```bash
cd ~/wallaroo-tutorial/wallaroo/
make build-giles-all build-utils-cluster_shutdown-all \
  build-utils-data_receiver-all
```

## Register

Register today and receive a Wallaroo T-shirt and a one-hour phone consultation with Sean, our V.P. of Engineering, to discuss your streaming data questions. Not sure if you have a streaming data problem? Not sure how to go about architecting a streaming data system? Looking to improve an existing system? Not sure how Wallaroo can help? Sean has extensive experience and is happy to help you work through your questions.

Please register here: [https://www.wallaroolabs.com/register](https://www.wallaroolabs.com/register).

Your email address will only be used to facilitate the above.

## Conclusion

Awesome! All set. Time to try [running your first application](run-a-wallaroo-go-application.md).
