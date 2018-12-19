---
title: "Tips for using Wallaroo in Docker"
menu:
  docs:
    parent: "appendix"
    weight: 1
toc: true
---
In this section, we will cover some tips that can help facilitate the development process for users of the Wallaroo Docker image.

## Editing Wallaroo files within the Wallaroo Docker container

When we start the Wallaroo Docker image with the `-v /tmp/wallaroo-docker/wallaroo-{{% wallaroo-version %}}/wallaroo-src:/src/wallaroo` option, as described in the [Python Docker Installation Guide](/python-installation/python-docker-installation-guide#validate-your-installation) section, we will be creating a new directory locally at `/tmp/wallaroo-docker/wallaroo-{{% wallaroo-version %}}/wallaroo-src` if it does not exist. This directory will be populated with the Wallaroo source code when we start the container for the first time. It is to be noted that the Wallaroo Docker image will only copy the source code to an empty directory on the host so it is advised that you use an empty directory the first time you run the `docker run` command. The source code will persist on your machine until you decide to remove it. Throughout the documentation, we make the assumption that you've used the `-v` option with an empty directory and have the source code on your host machine.

Now, you can modify any of the Python example applications, located under `/tmp/wallaroo-docker/wallaroo-{{% wallaroo-version %}}/wallaroo-src/examples/python`, using the editor of your choice on your machine.

If you decide to not use the `-v` mount option for Wallaroo source code, code will be copied to `/src/wallaroo` only within the Docker container. You will have to use an editor within the container. Currently, only Vim is provided. Other editors can be installed via apt-get, however they will not persist after the container is killed. Any code changes will also not persist.

**Note:** When mounting a volume for the Wallaroo source code (ca. 104mb), we place it in the `/tmp` folder. Most hosts delete files in the `/tmp` directory after a certain period of time. If you'd like the code to persist, we advise using a different directory (ex. `$HOME/wallaroo-docker/wallaroo-{{% wallaroo-version %}}/wallaroo-src`).

## Installing Python modules in Virtualenv

When we start the Wallaroo Docker image with the `-v /tmp/wallaroo-docker/wallaroo-{{% wallaroo-version %}}/python-virtualenv:/src/python-virtualenv` option, as described in the [Python Docker Installation Guide](/python-installation/python-docker-installation-guide#validate-your-installation) section, we will be creating a new directory locally at `/tmp/wallaroo-docker/wallaroo-{{% wallaroo-version %}}/python-virtualenv` if it does not exist, which will create a persistent Python `virtualenv` directory on your machine.

Now, anytime you enter the Wallaroo Docker image with the `bash docker exec -it wally env-setup` command, you will automatically be in the Wallaroo `virtualenv` and can install modules using `pip install` or `easy_install`. These modules will persist even if you exit the container and re enter as long as you start with the same mount options for the `virtualenv` directory. It is to be noted that any modules that are installed via `apt-get` will not persist beyond the lifecycle of the container.
