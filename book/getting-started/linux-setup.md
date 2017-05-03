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

### Trusty Ubuntu: Add the LLVM apt repos to /etc/apt/sources.list

Open `/etc/apt/sources.list` and add the following lines to the end of
the file:

```
deb http://apt.llvm.org/trusty/ llvm-toolchain-trusty-3.9 main
deb-src http://apt.llvm.org/trusty/ llvm-toolchain-trusty-3.9 main
```

### Xenial Ubuntu: Add the LLVM apt repos to /etc/apt/sources.list

Open `/etc/apt/sources.list` and add the following lines to the end of
the file:

```
deb http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main
deb-src http://apt.llvm.org/xenial/ llvm-toolchain-xenial-3.9 main
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

## Install GCC 5

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

## Make sure apt is up to date

```bash
sudo apt-get update
```

## Install Pony compiler dependencies

```bash
sudo apt-get install -y build-essential git zlib1g-dev \
  libncurses5-dev libssl-dev
```

### Install prce2

Try installing via apt-get.

```bash
sudo apt-get install -y libpcre2-dev
```

*Note:* some older versions of Ubuntu do not supply a prce2
package. If you get an error that no package exists (`E: Package
'libpcre2-dev' has no installation candidate`) then you will need to
install from source like this:

```bash
cd ~/
wget ftp://ftp.csx.cam.ac.uk/pub/software/programming/pcre/pcre2-10.21.tar.bz2
tar xvf pcre2-10.21.tar.bz2
cd pcre2-10.21
./configure --prefix=/usr
make
sudo make install
```

### Installing ponyc

Now you need to install the Sendence fork of the Pony compiler `ponyc`. Run:

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

Next, you need to install `pony-stable`, a Pony dependency management library. Navigate to a directory where you will put the `pony-stable` repo and execute the following commands:

```bash
cd ~/
git clone https://github.com/ponylang/pony-stable
cd pony-stable
git checkout 0054b429a54818d187100ed40f5525ec7931b31b
make
sudo make install
```

## Install Docker

You'll need Docker (CE or EE) to run the Wallaroo metrics UI. There are [instructions](https://docs.docker.com/engine/installation/linux/ubuntu/) for getting Docker up and running on Ubuntu on the [Docker website](https://docs.docker.com/engine/installation/linux/ubuntu/).

## Install the Metrics UI

```bash
sudo docker pull sendence/wallaroo-metrics-ui:pre-0.0.1
```
