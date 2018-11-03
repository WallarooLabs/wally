# Setting Up Your Environment for Wallaroo in Docker

To get you up and running quickly with Wallaroo, we have provided a Docker image which includes Wallaroo and related tools needed to run and modify a few example applications. We should warn that this Docker image was created with the intent of getting users started quickly with Wallaroo and is not intended to be a fully customizable development environment or suitable for production.

## Installing Docker

### MacOS

There are [instructions](https://docs.docker.com/docker-for-mac/) for getting Docker up and running on MacOS on the [Docker website](https://docs.docker.com/docker-for-mac/).  We recommend the 'Standard' version of the 'Docker for Mac' package.

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/docker-for-mac/#general).

### Windows

There are [instructions](https://www.docker.com/docker-windows/) for getting Docker up and running on Windows on the [Docker website](https://docs.docker.com/docker-for-windows/). We recommend installing the latest stable release, as there are breaking changes to our commands on edge releases. Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/docker-for-windows/#general).

Currently, development is only supported for Linux containers within Docker.

### Linux Ubuntu

There are [instructions](https://docs.docker.com/engine/installation/linux/ubuntu/) for getting Docker up and running on Ubuntu on the [Docker website](https://docs.docker.com/engine/installation/linux/ubuntu/).

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/engine/installation/linux/linux-postinstall/#configure-docker-to-start-on-boot).

All of the Docker commands throughout the rest of this manual assume that you have permission to run Docker commands as a non-root user. Follow the [Manage Docker as a non-root user](https://docs.docker.com/engine/installation/linux/linux-postinstall/#manage-docker-as-a-non-root-user) instructions to set that up. If you don't want to allow a non-root user to run Docker commands, you'll need to run `sudo docker` anywhere you see `docker` for a command.

## Get the official Wallaroo image:

```bash
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/{{ docker_version_url }}
```

## What's Included in the Wallaroo Docker image

* **Go Compiler**: for compiling Wallaroo Go applications.

* **Giles Sender**: supplies data to Wallaroo applications over TCP.

* **Data Receiver**: receives data from Wallaroo over TCP.

* **Cluster Shutdown tool**: notifies the cluster to shut down cleanly.

* **Metrics UI**: receives and displays metrics for running Wallaroo applications.

* **Wallaroo Source Code**: full Wallaroo source code is provided, including Go example applications.

## Additional Windows Setup

There are a few extra recommended steps that Windows users should make before continuing on to starting the Wallaroo Docker image. These steps are needed in order to persist the Wallaroo source code onto your local machine from within the Wallaroo Docker container. This will allow code changes to persist beyond the lifecycle of a Docker container.

These steps are optional, but will require the removal of the `-v` options when starting the Wallaroo Docker image if you choose to opt out.

### Sharing your drive with Docker

You can find instructions for setting up a shared drive with Docker on Windows [here](https://docs.docker.com/docker-for-windows/#shared-drives).

The remainder of this tutorial assumes you shared the `C` drive, modify the commands as needed if sharing a different drive.

### Creating the Wallaroo directory

We'll need to create a directory for the Wallaroo source code.

To create the Wallaroo source code directory run the following command in Powershell or Command Prompt:

```bash
mkdir c:\wallaroo-docker\wallaroo-{{ book.wallaroo_version }}\wallaroo-src
```

Your Windows machine is now all set to continue!

## Conclusion

Awesome! All set. Time to try running your first Wallaroo application in Docker.
