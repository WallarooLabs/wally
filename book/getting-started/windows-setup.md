# Setting Up Your Windows Environment for Wallaroo

These instructions have been tested on Windows 10 Pro version 1607 build 14393.x and version 1703 build 15063.x.

There are a few applications/tools which are required to be installed before you can proceed with the setup of the Wallaroo environment.

## Install Bash on Ubuntu on Windows

You'll need Bash on Ubuntu on Windows to build and run Wallaroo applications. There are [instructions](https://msdn.microsoft.com/en-us/commandline/wsl/install_guide) for getting Bash on Ubuntu on Windows setup on the [Windows website](https://msdn.microsoft.com/en-us/commandline/wsl/about). Installing Bash on Ubuntu on Windows will allow you to build and run Wallaroo applications as you would in a Linux environment.

## Linux Setup

Once you've installed Bash/WSL and can successfully start `bash` from a Command Prompt or Powershell, please follow the Ubuntu setup [instructions](linux-setup.md).

Run `lsb_release -a` inside of a `bash` shell in order to determine your release version. if the release output is 14.04 you are running Ubuntu Trusty, if it's 16.04 you are running Xenial, and if it's 18.04 you are running Bionic. Make sure to follow the proper instructions for the release you are running.

## Conclusion

Awesome! All set. Remember in order to run any of the Wallaroo build/run commands you must be in a `bash` shell. Time to try running your first application.
