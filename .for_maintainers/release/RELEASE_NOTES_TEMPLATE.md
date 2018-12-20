# Release Notes

Overview of release and what is included.

## Table of Contents
1. [Added](#added)
    - [example](#example)
2. [Changed](#changed)
3. [Fixed](#fixed)
4. [Upgrading Wallaroo](#upgrading-wallaroo)
    - [Upgrading Wallaroo when compiled from source](#upgrading-wallaroo-when-compiled-from-source)
    - [Upgrading Wallaroo via Wallaroo Up](#upgrading-wallaroo-up)
    - [Upgrading Wallaroo in Docker](#upgrading-wallaroo-in-docker)
    - [Upgrading Wallaroo in Vagrant](#upgrading-wallaroo-in-vagrant)
5. [CHANGELOG](#changelog)

<a name="added"></a>
## Added

<a name="example"></a>
### Example

<a name="changed"></a>
## Changed

<a name="fixed"></a>
## Fixed

<a name="upgrading-wallaroo"></a>
## Upgrading Wallaroo

In all cases below, if you run into issues, please reach out to us! We’re available on [twitter](https://twitter.com/wallaroolabs), [IRC](https://webchat.freenode.net/?channels=#wallaroo), [Github](https://github.com/WallarooLabs/wallaroo), [by email](mailto:hello@wallaroolabs.com), or [our mailing list](https://groups.io/g/wallaroo).
We love questions!

**If you have made no changes to Wallaroo or Pony since installation, your best bet will be to start from scratch, following the [instructions](https://docs.wallaroolabs.com/python-installation/) of your choice.**

Below are instructions for [Upgrading Wallaroo when compiled from source](#upgrading-wallaroo-when-compiled-from-source), [Upgrading Wallaroo in Docker](#upgrading-wallaroo-in-docker), [Upgrading Wallaroo in Vagrant](#upgrading-wallaroo-in-vagrant), and [Upgrading Wallaroo via Wallaroo Up](#upgrading-wallaroo-up).

<a name="upgrading-wallaroo-when-compiled-from-source"></a>
### Upgrading Wallaroo when compiled from source

These instructions are for Ubuntu Linux. It's assumed that if you are using a different operating system then you are able to translate these instructions to your OS of choice.

#### Upgrading ponyc to x.x.x

`ponyc` can be upgraded with the following command:

```bash
sudo apt-get install --only-upgrade ponyc=x.x.x
```

Verify you are now on the correct version of ponyc by running:

```bash
ponyc --version
```

You should get the following output:

```bash
x.x.x [release]
```

#### How to Upgrade Wallaroo

Once you're on the latest ponyc and pony stable, you're ready to switch over to Wallaroo x.x.x.

If you have made prior changes to the Wallaroo code, you’ll need to re-implement those changes. To get the latest release, assuming that you previously installed to the directory we recommended in setup, you’ll need to run the following:

```bash
cd ~/wallaroo-tutorial/
```

To get a new copy of the Wallaroo repository, run the following commands:

```bash
cd ~/wallaroo-tutorial/
curl -L -o wallaroo-x.x.x.tar.gz 'https://wallaroo-labs.bintray.com/wallaroolabs-ftp/wallaroo/x.x.x/wallaroo-x.x.x.tar.gz'
mkdir wallaroo-x.x.x
tar -C wallaroo-x.x.x --strip-components=1 -xzf wallaroo-x.x.x.tar.gz
rm wallaroo-x.x.x.tar.gz
cd wallaroo-x.x.x
```

You can then run the following commands to build the necessary tools to continue developing using Wallaroo x.x.x:

```bash
cd ~/wallaroo-tutorial/wallaroo-x.x.x
make build-machida build-giles-all build-utils-cluster_shutdown
```

<a name="upgrading-wallaroo-in-docker"></a>
### Upgrading the Wallaroo Docker image

To upgrade the Wallaroo Docker image, run the following command to get the latest image.  If you don't allow a non-root user to run Docker commands, you'll need to add `sudo` to the front of the command.

```bash
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/release/wallaroo:x.x.x
```

#### Upgrading Wallaroo Source Code

If you mounted the Wallaroo source code to your local machine using the directory recommended in setup, in  `/tmp/wallaroo-docker` (UNIX & MacOS users) or `c:/wallaroo-docker` (Windows users), then you will need to move the existing directory in order to get the latest source code.  The latest Wallaroo source code will be copied to this directory automatically when a new container is started with the latest Docker image.

##### UNIX & MacOS Users
For UNIX users, you can move the directory with the following command:

```bash
mv /tmp/wallaroo-docker/wallaroo-src/ /tmp/wallaroo-docker/wallaroo-x.x.x-src/
```

##### Windows Users
For Windows users, you can move the directory with the following command:
```bash
move c:/wallaroo-docker/wallaroo-src/ c:/wallaroo-docker/wallaroo-x.x.x-src
```


Once done moving, you can re-create the `wallaroo-src` directory with the following command:

```bash
mkdir c:\wallaroo-docker\wallaroo-src
```

<a name="upgrading-wallaroo-in-vagrant"></a>
### Upgrading Wallaroo in Vagrant

To upgrade your Wallaroo installation in Vagrant, you’ll want to follow the latest installation instructions for [Wallaroo in Vagrant](https://docs.wallaroolabs.com/python-installation/python-vagrant-installation-guide/).

Finally, to provision your new Vagrant box, run the following commands:

```bash
cd ~/wallaroo-tutorial/wallaroo-x.x.x/vagrant
vagrant up
```

If you have modified your old Vagrant VM in any way that you intend to persist, you’ll need to do that now.  For example, copy any edited or new files from the old Vagrant VM to the new one. When you’ve completed that, it’s a good idea to clean up your old Vagrant box, by running:

```bash
cd ~/wallaroo-tutorial/wallaroo-x.x.x/vagrant
vagrant destroy
```

<a name="upgrading-wallaroo-up"></a>
### Upgrading Wallaroo via Wallaroo Up


<a name="changelog"></a>
## CHANGELOG

### [x.x.x] - YYYY-MM-DD

#### Added

- example item

#### Changed

#### Fixed
