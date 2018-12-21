# Building and pushing Wallaroo Documentation Gitbook

This document is aimed at members of the Wallaroo team who might be building and pushing the Wallaroo Documentation Gitbook for a release candidate, release, or master branch. It serves as a checklist that can take your through the gitbook release process step-by-step.

To learn more about our release process, see [RELEASE.md](RELEASE.md).

## Prerequisites for building and pushing Wallaroo Documentation Gitbook

In order to build and push the Wallaroo Documentation Gitbook, you absolutely must have:

* Provisioned the Wallaroo Release Vagrant box as described in [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md) and ssh'ed into it.

## Building and pushing Wallaroo Documentation Gitbook

Please note that this document was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo. The `github-release.sh` script assumes you are using the `release` branch, `master` branch, or a release candidate branch that follows the `release-*` format.

### Pull latest changes for your branch

From within the Wallaroo Vagrant box, you'll want to run a `git pull` for the branch you plan to use to build and release the Wallaroo Documentation Gitbook like so:

```bash
cd ~/wallaroo
git checkout origin/RELEASE_BRANCH
git pull
```

So if you were going to release the Wallaroo Documentation Gitbook using `release-0.4.0`, you'd run the following:

```bash
cd ~/wallaroo
git checkout origin/release-0.4.0
git pull
```

### Building and pushing the Wallaroo Documentation Gitbook

From within the Wallaroo Vagrant box run the following:

```bash
cd /users/ubuntu/wallaroo
bash .release/documentation-release.sh VERSION COMMIT
```

So, for example, if your version is release-0.4.0 and your commit is `0xa0ece`, you'd run:

```bash
bash .release/documentation-release.sh release-0.4.0 0xa0ece
```

This will then build and push the Wallaroo Documentation Gitbook to the `wallaroolabs/docs.wallaroolabs.com` Github repository.
