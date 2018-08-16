# Releasing the Wallaroo source archive and Metrics UI AppImage for a release candidate or release branch

This document is aimed at members of the Wallaroo team who might be releasing the Wallaroo source archive and Metrics UI AppImage for a release candidate or release branch. It serves as a checklist that can take your through the Bintray artifacts release process step-by-step.

To learn more about our release process, see [RELEASE.md].

## Prerequisites for releasing the Bintray Artifacts

In order to release the Bintray artifacts, you absolutely must have:

* Vagrant installed
* Provisioned the Wallaroo Release Vagrant box as described in [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md).

## Releasing the Bintray Artifacts

Please note that this document was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo. The `bintray-artifacts-release.sh` script assumes you are using the `release` branch or a release candidate branch that follows the `release-*` format.

### Start up the Wallaroo Vagrant box

From the top level `wallaroo` directory run the following:

```bash
cd  .release
vagrant up
```

This command will bring up a vagrant box with Wallaroo's build and release dependencies installed and with the `wallaroo` repo cloned to `/users/ubuntu/wallaroo`.

### SSH into Wallaroo Vagrant box

From within the `.release` directory run:

```bash
vagrant ssh
```

This will `ssh` you into the running Wallaroo box.

### Pull latest changes for your branch

From within the Wallaroo Vagrant box, you'll want to run a `git pull` for the branch you plan to use to release the Wallaroo source archive and Metrics UI AppImage like so:

```bash
cd ~/wallaroo
git checkout origin/RELEASE_BRANCH
git pull
```

So if you were going to release the Bintray artifacts using `release-0.4.0`, you'd run the following:

```bash
cd ~/wallaroo
git checkout origin/release-0.4.0
git pull
```

### Releasing the Wallaroo source archive and Metrics UI AppImage

From within the Wallaroo Vagrant box run the following:

```bash
cd /users/ubuntu/wallaroo
bash .release/bintray-artifacts-release.sh RELEASE_VERSION RELEASE_COMMIT
```

So, for example, if you are releasing version `0.4.0` from commit `8a8ee28` then your command would be:

```bash
bash .release/bintray-artifacts-release.sh 0.4.0 8a8ee28
```

This will then build and upload the Wallaroo source archive and Metrics UI AppImage for the provided version and commit to Bintray. If using the `release` branch, images will be uploaded to `https://bintray.com/wallaroo-labs/wallaroolabs-rc/wallaroo` and if using a `release-*` branch, images will be uploaded to `https://bintray.com/wallaroo-labs/wallaroolabs-ftp/wallaroo`


### Stop the Wallaroo Vagrant Box

Once you've successfully built and uploaded the Wallaroo source archive and Metrics UI AppImage, you can stop the Wallaroo Vagrant box with the following command from within the `.release` directory on your local machine:

```bash
vagrant halt
```
