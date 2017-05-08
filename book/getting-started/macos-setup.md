# Setting Up Your MacOS Environment for Wallaroo

These instructions have been tested on OSX El Capitan and MacOS Sierra. 

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment. 

## Installing Xcode Command Line Tools

If you do not already have Xcode installed, you can run the following in a terminal window:

```bash
xcode-select --install
```

You can then click “Install” to download and install Xcode Command Line Tools.

## Installing Homebrew

Homebrew is used for easy installation of certain packages needed by Pony.

Instructions for installing Homebrew can be found [on their website](http://brew.sh/).

## Installing git

If you do not already have Git installed, install it via homebrew:

```bash
brew install git
```

## Installing the Pony Compiler

### Installing Pony Compiler Dependencies

You'll need LLVM 3.9.1, LibreSSL, and the pcre2 library to build Pony and compile Wallaroo apps.

Installation via [Homebrew](http://brew.sh):

```bash
$ brew update
$ brew install llvm@3.9
$ brew link --overwrite --force llvm@3.9
$ brew install pcre2 libressl
```

### Installing ponyc

Now you need to install the Sendence fork of the Pony compiler `ponyc`.

```bash
cd ~/
git clone https://github.com/sendence/ponyc
cd ponyc
git checkout sendence-19.2.8
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

## Install Docker

You'll need Docker to run the Wallaroo metrics UI. There are [instructions](https://docs.docker.com/docker-for-mac/) for getting Docker up and running on MacOS on the [Docker website](https://docs.docker.com/docker-for-mac/). Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/docker-for-mac/#general).

## Install the Metrics UI

```bash
docker pull sendence/wallaroo-metrics-ui:pre-0.0.1
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
git clone https://github.com/sendence/wallaroo
git checkout 0.0.1-rc5
```

Note: You need to login to GitHub for credentials

This will create a subdirectory called `wallaroo`.

## Conclusion

Awesome! All set. Time to try running your first application.
