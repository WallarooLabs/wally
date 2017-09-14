# Setting Up Your MacOS Environment for Wallaroo

These instructions have been tested on OSX El Capitan and MacOS Sierra.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Installing Xcode Command Line Tools

If you do not already have Xcode installed, you can run the following in a terminal window:

```bash
xcode-select --install
```

You can then click “Install” to download and install Xcode Command Line Tools.

## Installing a Package Manager, Homebrew

Homebrew is used for easy installation of certain packages needed by Pony.

Instructions for installing Homebrew can be found [on their website](http://brew.sh/).  This book assumes that you use the default installation directory, `/usr/local`.  If you choose an alternate installation directory, please configure your shell's `PATH` environment variable as needed.

**NOTE:** For users of the MacPorts package manager, we strongly recommend *not* using MacPorts.  It is extremely difficult to install correctly the compiler toolchain required by Wallaroo using only MacPorts.

## Installing git

If you do not already have Git installed, install it via Homebrew:

```bash
brew install git
```

## Installing the Pony Compiler

### Installing Pony Compiler Dependencies

You'll need LLVM 3.9.1, LibreSSL, and the pcre2 library to build Pony and compile Wallaroo apps.  Also, the next section will use the `wget` utility to help install the Pony language compiler.

Use the following commands to install via [Homebrew](http://brew.sh):

```bash
brew update
brew install llvm@3.9
brew link --overwrite --force llvm@3.9
brew install pcre2 libressl wget
```

### Installing ponyc

Now you need to install the Wallaroo Labs fork of the Pony compiler `ponyc`.

```bash
cd ~/
wget https://github.com/WallarooLabs/ponyc/archive/wallaroolabs-19.2.14.tar.gz
tar xzfv wallaroolabs-19.2.14.tar.gz
cd ponyc-wallaroolabs-19.2.14
sudo make config=release install
```

You can check that the installation was successful by running:

```bash
ponyc examples/helloworld
./helloworld
```

## Installing pony-stable

Next, you need to install `pony-stable`, a Pony dependency management library:

```bash
cd ~/
git clone https://github.com/ponylang/pony-stable
cd pony-stable
git checkout 0054b429a54818d187100ed40f5525ec7931b31b
make
sudo make install
```

## Install Compression Development Libraries

Wallaroo's Kakfa support requires a `libsnappy` and `liblz` to be installed.

```bash
brew install snappy lz4
```

## Install Python Development Libraries

```bash
brew install python
```

## Install Docker

You'll need Docker to run the Wallaroo metrics UI. There are [instructions](https://docs.docker.com/docker-for-mac/) for getting Docker up and running on MacOS on the [Docker website](https://docs.docker.com/docker-for-mac/).  We recommend the 'Standard' version of the 'Docker for Mac' package.

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/docker-for-mac/#general).

## Install the Metrics UI

```bash
docker pull sendence/wallaroo-metrics-ui:0.1
```

## Set up Environment for the Wallaroo Tutorial

Create a directory called `~/wallaroo-tutorial` and navigate there by running

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
git checkout release-0.1.0-rc3
```

This will create a subdirectory called `wallaroo`.

## Installing Machida

Machida is the program that runs Wallaroo Python applications. Change to the `machida` directory:

```bash
cd ~/wallaroo-tutorial/wallaroo/machida
make
```

## Install Giles Sender

Giles Sender is used to supply data to Wallaroo applications over TCP.

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/sender
make
```

## Install Giles Receiver

Giles Receiver receives data from Wallaroo over TCP.

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/receiver
make
```

## Install Cluster Shutdown tool

The Cluster Shutdown tool is used to tell the cluster to shut down cleanly.

```bash
cd ~/wallaroo-tutorial/wallaroo/utils/cluster_shutdown
make
```

## Conclusion

Awesome! All set. Time to try running your first application.
