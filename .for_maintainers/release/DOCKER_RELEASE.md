# Releasing the Wallaroo and Metrics UI Docker images for a release candidate or release branch

This document is aimed at members of the Wallaroo team who might be releasing the Wallaroo and Metrics UI Docker images for a release candidate or release branch. It serves as a checklist that can take your through the Docker image release process step-by-step.

To learn more about our release process, see [RELEASE.md](RELEASE.md).

## Prerequisites for releasing the Docker images

In order to release the Docker images, you absolutely must have:

* Provisioned the Wallaroo Release Vagrant box as described in [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md) and ssh'ed into it.

## Releasing the Docker images

Please note that this document was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo. The `docker-release.sh` script assumes you are using the `release` branch or a release candidate branch that follows the `release-*` format.

### Pull latest changes for your branch

From within the Wallaroo Vagrant box, you'll want to run a `git pull` for the branch you plan to use to release the Wallaroo and Metrics UI Docker images like so:

```bash
cd ~/wallaroo
git checkout origin/RELEASE_BRANCH
git pull
```

So if you were going to release the Docker images using `release-0.4.0`, you'd run the following:

```bash
cd ~/wallaroo
git checkout origin/release-0.4.0
git pull
```

### Releasing the Wallaroo and Metrics UI images

From within the Wallaroo Vagrant box run the following:

```bash
cd /users/ubuntu/wallaroo
bash .release/docker-release.sh RELEASE_VERSION RELEASE_COMMIT
```

So, for example, if you are releasing version `0.4.0` from commit `8a8ee28` then your command would be:

```bash
bash .release/docker-release.sh 0.4.0 8a8ee28
```

This will then build and push the Wallaroo and Metrics UI images for the provided version and commit to Bintray. If using the `release` branch, images will be hosted under `wallaroo-labs-docker-wallaroolabs.bintray.io/release` and if using a `release-*` branch, images will be hosted under `wallaroo-labs-docker-wallaroolabs.bintray.io/dev`
