# Provisioning Vagrant

This document is aimed at members of the Wallaroo team who might be cutting a release of Wallaroo. It serves as a checklist to ensure you're setup to provision the Wallaroo Vagrant release box.

## Prerequisites

in order to properly provision the Vagrant box used for the Wallaroo release process you will need the following:

- **WallarooLabs Bintray Docker Credentials:** You will need a Docker Username and API Key setup via Bintray with access to the `wallaroo-labs-docker-wallaroolabs.bintray.io` Docker repository. Please note that you MUST be a member of the `wallaroo-labs/wallaroolabs` Bintray Docker repository in order to have publish access. If you need access, contact @seanTallen or @JONBRWN before continuing.

To verify that your newly-generated Bintray API Token works, you can run the following command:

```bash
docker login -u <YOUR_BINTRAY_USER> -p <YOUR_BINTRAY_API_KEY> wallaroo-labs-docker-wallaroolabs.bintray.io
```


- **`~/.gitconfig` file:** the `.release/Vagrantfile` expects a `.gitconfig` file to exist under `~/.gitconfig` on the host, which will be shared with the Vagrant box for committing purposes.

- **Github SSH access on host:** Pushing and pulling via Git/Github will occur via ssh forwarding between the host and Vagrant box. Due to this, it is assumed that your host can access Github via ssh. (see: https://help.github.com/articles/connecting-to-github-with-ssh/)

## Provision the Wallaroo Release Vagrant Box

To provision the Wallaroo Release Vagrant Box run the following from the root Wallaroo directory:

```bash
cd .release
DOCKER_USERNAME=<YOUR_USERNAME> DOCKER_PASSWORD=<YOUR_BINTRAY_DOCKER_API_ACCESS_KEY> DOCKER_SERVER=wallaroo-labs-docker-wallaroolabs.bintray.io vagrant up
```

Once successfully provisioned, you can ssh into the Vagrant box with the following command:

```bash
vagrant ssh
```
