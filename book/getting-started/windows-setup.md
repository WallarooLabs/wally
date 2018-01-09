# Setting Up Your Windows Environment for Wallaroo

These instructions have been tested on Windows 10 Pro version 1607 build 14393.x and version 1703 build 15063.x.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Install Docker

You'll need Docker for Windows to run the Wallaroo metrics UI. There are [instructions](https://docs.docker.com/docker-for-windows/install/) for getting Docker up and running on Windows on the [Docker website](https://docs.docker.com/docker-for-windows/). Installing Docker will result in it running on your machine. In order to be able to use Docker for Windows, you must be running a 64bit version of Windows 10 Pro and Microsoft Hyper-V with virtualization enabled.

## Install the Metrics UI

```bash
docker pull wallaroo-labs-docker-wallaroolabs.bintray.io/release/metrics_ui:{{ book.wallaroo_version }}
```

## Install Bash on Ubuntu on Windows

You'll need Bash on Ubuntu on Windows to build and run Wallaroo applications. There are [instructions](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide) for getting Bash on Ubuntu on Windows setup on the [Windows website](https://msdn.microsoft.com/en-us/commandline/wsl/about). Installing Bash on Ubuntu on Windows will allow you to build and run Wallaroo applications as you would in a Linux environment.

## Linux Setup

Once you've installed Bash/WSL and can successfully start `bash` from a Command Prompt or Powershell, please follow the Ubuntu setup [instructions](linux-setup.md).

Run `lsb_release -a` inside of a `bash` shell in order to determine your release version. if the release output is 14.04 you are running Ubuntu Trusty and if it's 16.04 you are running Xenial. Make sure to follow the proper instructions for the release you are running.

Since you have setup Docker on Windows, do ignore any Docker related setup instructions for Linux.

## Conclusion

Awesome! All set. Remember in order to run any of the Wallaroo build/run commands you must be in a `bash` shell. Any Docker related commands should be run in a Command Prompt or Powershell. Time to try running your first application.
