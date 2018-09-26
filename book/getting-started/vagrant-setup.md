# Setting Up Your Environment for Wallaroo in Vagrant

To get you up and running quickly with Wallaroo, we have provided a Vagrantfile which includes Wallaroo and related tools needed to run and modify a few example applications. We should warn that this Vagrantfile was created with the intent of getting users started quickly with Wallaroo and is not intended to be suitable for production. Wallaroo in Vagrant runs on Ubuntu Linux Xenial.

## Set up Environment for the Wallaroo Tutorial

### Linux Ubuntu and MacOS

If you haven't already done so, create a directory called `~/wallaroo-tutorial` and navigate there by running:

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. Download the Wallaroo sources (this will create a subdirectory called `wallaroo-{{ book.wallaroo_version }}`):

```bash
curl -L -o wallaroo-{{ book.wallaroo_version }}.tar.gz '{{ book.bintray_repo_url }}/wallaroo/{{ book.wallaroo_version }}/wallaroo-{{ book.wallaroo_version }}.tar.gz'
mkdir wallaroo-{{ book.wallaroo_version }}
tar -C wallaroo-{{ book.wallaroo_version }} --strip-components=1 -xzf wallaroo-{{ book.wallaroo_version }}.tar.gz
rm wallaroo-{{ book.wallaroo_version }}.tar.gz
cd wallaroo-{{ book.wallaroo_version }}
```

### Windows via Powershell

**Note:** This section of the guide assumes you are using Powershell.

Download and install git from [Git for Windows](https://gitforwindows.org/) and install it.

If you haven't already done so, create a directory called `~/wallaroo-tutorial` and navigate there by running:

```bash
cd ~/
mkdir ~/wallaroo-tutorial
cd ~/wallaroo-tutorial
```

This will be our base directory in what follows. If you haven't already cloned the Wallaroo repo, do so now (this will create a subdirectory called `wallaroo-{{ book.wallaroo_version }}`):

```bash
git clone https://github.com/WallarooLabs/wallaroo wallaroo-{{ book.wallaroo_version }}
cd wallaroo-{{ book.wallaroo_version }}
git checkout {{ book.wallaroo_version }}
```

## Installing VirtualBox

The Wallaroo Vagrant environment is dependent on the default provider,[VirtualBox](https://www.vagrantup.com/docs/virtualbox/). To install VirtualBox, download a installer or package for your OS [here](https://www.virtualbox.org/wiki/Downloads). Linux users can also use `apt-get` as documented below.

### Linux

```bash
sudo apt-get install virtualbox
```

## Installing Vagrant

### Linux Ubuntu, MacOS, and Windows

Download links for the appropriate installer or package for each supported OS can be found on the [Vagrant downloads page](https://www.vagrantup.com/downloads.html).

## Provision the Vagrant Box

Provisioning should take about 10 to 15 minutes. When it finishes, you will have a complete Wallaroo development environment. You won’t have to go through the provisioning process again unless you destroy the Wallaroo environment by running `vagrant destroy`.

To provision, run the following commands:

```bash
cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/vagrant
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
cd ~/wallaroo-tutorial/wallaroo-{{ book.wallaroo_version }}/vagrant
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
