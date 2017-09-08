# Setting Up Your Ubuntu Environment for Wallaroo

These instructions have been tested for Ubuntu Trusty and Xenial releases.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Installing git

If you do not already have Git installed, install it:

```bash
sudo apt-get install git
```

## Install LLVM 3.9

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

### Add the LLVM repo as a trusted source

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

### Install GCC 5 or Higher

You'll need to be using at least `gcc-5`. We rely on its atomics support. If you have at least `gcc-5` installed on your machine, you don't need to do anything. If you have gcc 4 or lower, you'll need to upgrade. You can check you `gcc` version by running:

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

### Install prce2

#### Xenial Ubuntu:

```bash
sudo apt-get install -y libpcre2-dev
```

#### Trusty Ubuntu:

*Note:* some older versions of Ubuntu do not supply a prce2
package. If you get an error that no package exists (`E: Package
'libpcre2-dev' has no installation candidate`) then you will need to
install from source like this:

```bash
cd ~/
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2
tar xjvf pcre2-10.21.tar.bz2
cd pcre2-10.21
./configure --prefix=/usr
make
sudo make install
```

### Installing ponyc

Now you need to install the Wallaroo Labs fork of the Pony compiler `ponyc`. Run:

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

Next, you need to install `pony-stable`, a Pony dependency management library. Navigate to a directory where you will put the `pony-stable` repo and execute the following commands:

```bash
cd ~/
git clone https://github.com/ponylang/pony-stable
cd pony-stable
git checkout 0054b429a54818d187100ed40f5525ec7931b31b
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

## Install the Metrics UI

```bash
sudo docker pull sendence/wallaroo-metrics-ui:pre-0.0.1
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
git checkout 0.0.1-rc15
```

Note: You need to login to GitHub for credentials

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

## Conclusion

Awesome! All set. Time to try running your first application.
