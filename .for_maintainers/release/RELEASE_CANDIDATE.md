# How to create a Wallaroo release candidate

This document is aimed at members of the Wallaroo team who might be creating a Wallaroo release candidate. It serves as a checklist that can take your through the creation process step-by-step.

To learn more about our release process, see [RELEASE.md](RELEASE.md).

## Prerequisites for creating any release candidate

In order to do a release candidate, you absolutely must have:

* Provisioned the Wallaroo Release Vagrant box as described in [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md) and ssh'ed into it.

## Prerequisites for specific release candidate

Before getting started, you will need a number for the version that you will be releasing as well as an agreed upon "golden commit" that will form the basis of the release.  Any commit is eligible to be a "golden commit" so long as:

* It's on `master` or the `release` branch
* It passed all CI checks

## Cutting a release candidate

Please note that the release script was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo. It is assumed that you are running this script within the Wallaroo Release Vagrant Box.

Cutting a release candidate is a simple process. Run the script with the correct arguments and you are done. The release candidate script is run with the following format:

```bash
bash .release/rc.sh MY_VERSION MY_GOLDEN_COMMIT
```

So, for example, if you are releasing version `release-0.4.0` from golden commit `8a8ee28` then your command would be:

```bash
bash .release/rc.sh release-0.4.0 8a8ee28
```

The script will make changes on in your local Wallaroo repo and will prompt you before pushing them back to GitHub.
