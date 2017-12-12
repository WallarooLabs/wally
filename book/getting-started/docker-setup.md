# Setting Up Your Environment for Wallaroo in Docker

To get you up and running quickly with Wallaroo, we have provided a Docker image which includes Wallaroo and related tools needed to run and modify a few example applications. We should warn that this Docker image was created with the intent of getting users started quickly with Wallaroo and is not intended to be a fully customizable development environment or suitable for production. MacOS Sierra and High Sierra users are recommended to install via Docker to avoid a kernel panic caused by a few Wallaroo applications, this is currently under investigation.

## Installing Docker

### MacOS

There are [instructions](https://docs.docker.com/docker-for-mac/) for getting Docker up and running on MacOS on the [Docker website](https://docs.docker.com/docker-for-mac/).  We recommend the 'Standard' version of the 'Docker for Mac' package.

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/docker-for-mac/#general).

### Linux Ubuntu

There are [instructions](https://docs.docker.com/engine/installation/linux/ubuntu/) for getting Docker up and running on Ubuntu on the [Docker website](https://docs.docker.com/engine/installation/linux/ubuntu/).

Installing Docker will result in it running on your machine. After you reboot your machine, that will no longer be the case. In the future, you'll need to have Docker running in order to use a variety of commands in this book. We suggest that you [set up Docker to boot automatically](https://docs.docker.com/engine/installation/linux/linux-postinstall/#configure-docker-to-start-on-boot).

All of the Docker commands throughout the rest of this manual assume that you have permission to run Docker commands as a non-root user. Follow the [Manage Docker as a non-root user](https://docs.docker.com/engine/installation/linux/linux-postinstall/#manage-docker-as-a-non-root-user) instructions to set that up. If you don't want to allow a non-root user to run Docker commands, you'll need to run `sudo docker` anywhere you see `docker` for a command.

## Get the official Wallaroo image from [Bintray](https://bintray.com/wallaroo-labs/wallaroolabs/first-install%3Awallaroo):

```bash
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/dev/wallaroo:e089428
```

## What's Included in the Wallaroo Docker image

- **Machida**: runs Wallaroo Python applications.

- **Giles Sender**: supplies data to Wallaroo applications over TCP.

- **Giles Receiver**: receives data from Wallaroo over TCP.

- **Cluster Shutdown tool**: notifies the cluster to shut down cleanly.

- **Metrics UI**: receives and displays metrics for running Wallaroo applications.

- **Wallaroo Source Code**: full Wallaroo source code is provided, including Python example applications.

## Conclusion

Awesome! All set. Time to try running your first Wallaroo application in Docker.
