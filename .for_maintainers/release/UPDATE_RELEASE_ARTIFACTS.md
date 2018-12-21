# Releasing all the Wallaroo artifacts for a release

This document is aimed at members of the Wallaroo team who might be releasing the Wallaroo artifacts release candidate or release branch. It serves as a checklist that can take your through the Wallaroo artifacts release process step-by-step.

To learn more about our release process, see [RELEASE.md](RELEASE.md).

## Prerequisites for releasing the Wallaroo Artifacts

In order to release the Wallaroo artifacts, you absolutely must have:

* Provisioned the Wallaroo Release Vagrant box as described in [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md) and ssh'ed into it.

## Releasing the Wallaroo Artifacts

Please note that this document was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo. The `update-release-artifacts.sh` script assumes you are using the `release` branch or a release candidate branch that follows the `release-*` format.

### Pull latest changes for your branch

From within the Wallaroo Vagrant box, you'll want to run a `git pull` for the branch you plan to use to release the Wallaroo source archive and Metrics UI AppImage like so:

```bash
cd ~/wallaroo
git checkout origin/RELEASE_BRANCH
git pull
```

So if you were going to release the Wallaroo artifacts using `release-0.4.0`, you'd run the following:

```bash
cd ~/wallaroo
git checkout origin/release-0.4.0
git pull
```

### Releasing the updated artifacts

From within the Wallaroo Vagrant box run the following for a Release Candidate:

```bash
cd ~/wallaroo
bash .release/update-release-artifacts.sh release-RELEASE_VERSION RELEASE_COMMIT
```

So, for example, if you are releasing the RC for `0.4.0` from commit `8a8ee28` then your command would be:

```bash
bash .release/update-release-artifacts.sh release-0.4.0 8a8ee28
```

From within the Wallaroo Vagrant box run the following for a final release:

```bash
cd ~/wallaroo
bash .release/update-release-artifacts.sh RELEASE_VERSION RELEASE_COMMIT
```

So, for example, if you are releasing version `0.4.0` from commit `8a8ee28` then your command would be:

```bash
bash .release/update-release-artifacts.sh 0.4.0 8a8ee28
```

This will then ensure the following are built and released:

* the Wallaroo RC/release source archive and Metrics UI RC AppImage to Bintray (documented in [DOCKER_RELEASE.md](DOCKER_RELEASE.md)).
* the Wallaroo and Metrics UI RC/release Docker images on Bintray ([BINTRAY_ARTIFACTS_RELEASE.md](BINTRAY_ARTIFACTS_RELEASE.md)).
* the RC/release Documentation ([DOCUMENTATION_RELEASE.md](DOCUMENTATION_RELEASE.md)).
