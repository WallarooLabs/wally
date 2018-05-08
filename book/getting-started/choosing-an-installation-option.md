# Choosing an Installation Option for Wallaroo

For MacOS and Windows users, we currently provide two different ways for a user to install Wallaroo: [Installing with Docker](/book/getting-started/docker-setup.md) and [Installing with Vagrant](/book/getting-started-vagrant-setup.md). If you are unsure about which solution is right for you, a breakdown of each is provided below.

For Linux users, we currently provide three different ways for a user to install Wallaroo: [Installing with Docker](/book/getting-started/docker-setup.md), [Installing with Vagrant](/book/getting-started-vagrant-setup.md), and [Installing from Source](/book/getting-started/linux-setup.md). If you are unsure about which solution is right for you, we wanted to provide a breakdown of each approach.

## Installing with Docker

Installing with Docker provides the benefit of needing to install only one system dependency: Docker itself. We decided to provide this option due to the isolated environment provided by Docker containers and the quick start time. You won't need to install the system dependencies needed by Wallaroo to test it out, a huge benefit we assumed many first time users might be interested in. Once Docker is set up, the user will only need to run a `docker pull` and they will have Wallaroo and all of its support tools available to them within the Wallaroo Docker image. The Docker environment has limited customizability due to the nature of a container's lifecycle but we have provided options to persist both code changes and Python modules for users. We recommend this process for users looking to get started quickly and who do not rely on a heavily customized environment for development.

## Installing with Vagrant

Installing with Vagrant provides the benefit of needing to install only two system dependencies: git and Vagrant. We decided to provide this option due to the isolated environment provided by Vagrant boxes and the quick start time. You won't need to install the system dependencies needed by Wallaroo to test it out, a huge benefit we assumed many first time users might be interested in. Once Vagrant is set up and the user has a copy of the Wallaroo repository, the user will only need to run a `vagrant up` command from the `vagrant` directory and they will have Wallaroo and all of its support tools available to them within the Wallaroo Vagrant Box. We recommend this process for users looking to get started quickly who want a more customizable and long living environment for development.

## Installing from Source

Installing from source will allow our users to take full advantage of the development environment that they are used to. There is a bit of additional set up time due to the complexities of setting up a distributed data processing framework, but we believe that is outweighed by the user being able to use the tooling that they're most familiar with. We recommend this process for users who would prefer to use their development environment and do not mind the additional set up necessary for Wallaroo to be running on their machine.
