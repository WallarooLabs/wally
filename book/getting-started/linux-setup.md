# Setting Up Your Ubuntu Environment for Wallaroo

These instructions have been tested for Ubuntu Trusty and Xenial releases.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Memory requirements

In order to compile the Wallaroo example applications, your system will need to have approximately 6 GB working memory (this can be RAM or swap). If you don't have enough memory, you are likely to see that the compile process is `Killed` by the OS.

## Installing git

If you do not already have Git installed, install it:

```bash
sudo apt-get install git
```

<!-- ## Install LLVM 3.9

Visit [http://apt.llvm.org](http://apt.llvm.org) and select the correct apt mirror for you version of Ubuntu.

### Xenial Ubuntu: Add the LLVM apt repos to /etc/apt/sources.list

Open `/etc/apt/sources.list` and add the following lines to the end of
the file:

```
deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main
deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main
```

### Trusty Ubuntu: Add the LLVM apt repos to /etc/apt/sources.list

Open `/etc/apt/sources.list` and add the following lines to the end of
the file:

```
deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-3.9 main
deb-src http://apt.llvm.org/trusty/ llvm-toolchain-trusty-3.9 main
```
 -->
<!-- ### Add the LLVM repo as a trusted source

```bash
cd ~/
wget -O llvm-snapshot.gpg.key http://apt.llvm.org/llvm-snapshot.gpg.key
sudo apt-key add llvm-snapshot.gpg.key
```

### Install

```bash
sudo apt-get update
sudo apt-get install -y llvm-3.9
```

## Install Pony compiler dependencies

```bash
sudo apt-get install -y build-essential zlib1g-dev \
  libncurses5-dev libssl-dev
```
 -->
## Install make

```bash
sudo apt-get update
sudo apt-get install -y build-essential
```

### Install GCC 5 or Higher

You'll need to be using at least `gcc-5`. We rely on its atomics support. If you have at least `gcc-5` installed on your machine, you don't need to do anything. If you have gcc 4 or lower, you'll need to upgrade. You can check your `gcc` version by running:

```bash
gcc --version
```

To upgrade:

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

### Installing ponyc

Now you need to install Pony compiler `ponyc`. Run:

```bash
sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys "8756 C4F7 65C9 AC3C B6B8  5D62 379C E192 D401 AB61"
echo "deb https://dl.bintray.com/pony-language/ponyc-debian pony-language main" | sudo tee -a /etc/apt/sources.list
sudo apt-get update
sudo apt-get -V install ponyc
```

You can check that the installation was successful by running:

```bash
cd ~/
mkdir -p ponyc-example/helloworld
touch ponyc-example/helloworld/helloworld.pony
echo 'actor Main new create(env: Env) => env.out.print("Hello World\n")' \
  > ponyc-example/helloworld/helloworld.pony
ponyc ponyc-example/helloworld
./helloworld
```

## Installing pony-stable

Next, you need to install `pony-stable`, a Pony dependency management library. Navigate to a directory where you will put the `pony-stable` repo and execute the following commands:

```bash
cd ~/
git clone https://github.com/ponylang/pony-stable
cd pony-stable
git checkout 0.1.0
make
sudo make install
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
sudo docker pull wallaroolabs/wallaroo-metrics-ui:0.1
```

## Set up Environment for the Wallaroo Tutorial

Create a directory called `~/wallaroo-tutorial` and navigate there by running

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. If you haven't already cloned the Wallaroo repo, do so now (this will create a subdirectory called `wallaroo`):

```bash
git clone https://github.com/WallarooLabs/wallaroo
cd wallaroo
git checkout 0.1.2
```

## Compiling Machida

Machida is the program that runs Wallaroo Python applications. Change to the `machida` directory:

```bash
cd ~/wallaroo-tutorial/wallaroo/machida
make
```

## Compiling Giles Sender

Giles Sender is used to supply data to Wallaroo applications over TCP.

```bash
cd ~/wallaroo-tutorial/wallaroo/giles/sender
make
```

## Compiling Giles Receiver

Giles Receiver receives data from Wallaroo over TCP.


```bash
cd ~/wallaroo-tutorial/wallaroo/giles/receiver
make
```

## Compiling Cluster Shutdown tool

The Cluster Shutdown tool is used to tell the cluster to shut down cleanly.

```bash
cd ~/wallaroo-tutorial/wallaroo/utils/cluster_shutdown
make
```

## Conclusion

Awesome! All set. Time to try running your first application.
