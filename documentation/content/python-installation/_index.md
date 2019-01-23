---
title: "Choosing an Installation Option"
menu:
  toc:
    parent: "pyinstallation"
    weight: 1
toc: true
layout: single
---
For 64-bit MacOS and Windows users, we provide two different ways for you to install Wallaroo:

- [Wallaroo in Docker]({{< relref "python-docker-installation-guide.md" >}})
- [Wallaroo in Vagrant]({{< relref "python-vagrant-installation-guide.md" >}})

If you are unsure about which solution is right for you, a breakdown of each is provided below. (NOTE: Wallaroo does not support 32-bit platforms.)

For 64-bit Linux users, we provide three different ways for you to install Wallaroo.

- [Wallaroo Up]({{< relref "python-wallaroo-up-installation-guide.md" >}})
- [Wallaroo in Docker]({{< relref "python-docker-installation-guide.md" >}})
- [Wallaroo in Vagrant]({{< relref "python-vagrant-installation-guide.md" >}})

If you are unsure about which solution is right for you, we wanted to provide a breakdown of each approach. We recommend using Wallaroo Up.

## Installing with Docker

We recommend this process if you're looking to get started quickly and do not rely on a heavily customized environment for development.

Installing with Docker provides the benefit of needing to install only one system dependency: Docker itself. Once Docker is set up, you will only need to run a `docker pull` and you will have Wallaroo and all of its support tools available within the Wallaroo Docker image.

The Docker environment has limited customizability due to the nature of a container's lifecycle but we have provided options to persist both code changes and Python modules for you.

[Get started installing with Docker]({{< relref "python-docker-installation-guide.md" >}}/).

## Installing with Vagrant

We recommend this process if you're looking to get started quickly and want a more customizable and long living environment for development. This process is also recommended if you do not want to install or use Docker.

Installing with Vagrant provides the benefit of needing to install only two system dependencies: Virtualbox and Vagrant. Once Vagrant is set up and you have a copy of the Wallaroo codebase, you will only need to run a `vagrant up` command from the `vagrant` directory and you will have Wallaroo and all of its support tools available within the Wallaroo Vagrant Box.

[Get started installing with Vagrant]({{< relref "python-vagrant-installation-guide.md" >}}).

## Wallaroo Up

We recommend this process if you would prefer to use your development environment and do not mind the additional system requirements necessary for Wallaroo to be installed and running on your machine. The Wallaroo Up script automatically takes care of installing everything for setting up a Wallaroo development environment.

This process requires installing several system libraries which may conflict with requirements of other tools in your development environment. We recommmend reviewing the process before proceeding.

[Get started installing with Wallaroo Up]({{< relref "python-wallaroo-up-installation-guide.md" >}}).
