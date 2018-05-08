# Setting Up Your Environment for Wallaroo in Vagrant

To get you up and running quickly with Wallaroo, we have provided a Vagrantfile which includes Wallaroo and related tools needed to run and modify a few example applications. We should warn that this Vagrantfile was created with the intent of getting users started quickly with Wallaroo and is not intended to be suitable for production. Wallaroo in Vagrant runs on Ubuntu Linux Xenial.

**Note:** For Windows users, this section of the guide assumes you are using Powershell.

## Installing Git

### Linux Ubuntu

If you do not already have Git installed, install it:

```bash
sudo apt-get install git
```

### MacOS

#### Installing a Package Manager, Homebrew

Homebrew is used for easy installation of certain packages needed by Wallaroo.

Instructions for installing Homebrew can be found [on their website](http://brew.sh/).  This book assumes that you use the default installation directory, `/usr/local`.  If you choose an alternate installation directory, please configure your shell's `PATH` environment variable as needed.

If you do not already have Git installed, install it via Homebrew:

```bash
brew install git
```

### Windows

Download git from [Git for Windows](https://gitforwindows.org/) and install it.

## Set up Environment for the Wallaroo Tutorial

### Linux Ubuntu, MacOS, and Windows via Powershell

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

## Installing Vagrant

### Linux Ubuntu, MacOS, and Windows

Download links for the appropriate installer or package for each supported OS can be found on the [Vagrant downloads page](https://www.vagrantup.com/downloads.html).

## Provision the Vagrant Box

Provisioning should take about 10 to 15 minutes. When it finishes, you will have a complete Wallaroo development environment. You won’t have to go through the provisioning process again unless you destroy the Wallaroo environment by running `vagrant destroy`.

To provision, run the following commands:

```bash
cd ~/wallaroo-tutorial/wallaroo/vagrant
vagrant up
```

## What's Included in the Wallaroo Vagrant Box

* **Machida**: runs Wallaroo Python applications.

* **Giles Sender**: supplies data to Wallaroo applications over TCP.

* **Giles Receiver**: receives data from Wallaroo over TCP.

* **Cluster Shutdown tool**: notifies the cluster to shut down cleanly.

* **Metrics UI**: receives and displays metrics for running Wallaroo applications.

* **Wallaroo Source Code**: full Wallaroo source code is provided, including Python example applications.

## Shutdown the Vagrant Box

You can shut down the Vagrant Box by running the following on your host machine:

```bash
cd ~/wallaroo-tutorial/wallaroo/vagrant
vagrant halt
```

## Restart the Vagrant Box

If you need to restart the Vagrant Box you can run the following command from the same directory:

```bash
vagrant up
```

## Register

Register today and receive a Wallaroo T-shirt and a one-hour phone consultation with Sean, our V.P. of Engineering, to discuss your streaming data questions. Not sure if you have a streaming data problem? Not sure how to go about architecting a streaming data system? Looking to improve an existing system? Not sure how Wallaroo can help? Sean has extensive experience and is happy to help you work through your questions.

Please register here: [https://www.wallaroolabs.com/register](https://www.wallaroolabs.com/register).

Your email address will only be used to facilitate the above.

## Conclusion

Awesome! All set. Time to try running your first Wallaroo application in Vagrant.
