# How to promote a Wallaroo release candidate to a release

This document is aimed at members of the Wallaroo team who might be promoting a Wallaroo release candidate to a release. It serves as a checklist that can take your through the promotion process step-by-step.

To learn more about our release process, see [RELEASE.md](RELEASE.md).

## Prerequisites for promoting any release candidate to a release

In order to promote a release candidate to a release, you absolutely must have:

* Provisioned the Wallaroo Release Vagrant box as described in [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md) and ssh'ed into it.
* Commit access to the `wallaroo` `release` branch


## Prerequisites for specific release candidate to release promotion

Before getting started, you will need the number for the version that you will be releasing and the release candidate branch. Before continuing ensure the following of the release candidate branch:

* Includes the updated version for the upcoming release in the VERSION file
* It passed all CI checks on the latest commit

## Promoting a release candidate to a release

Please note that the release script was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo. It is assumed that you are running this script within the Wallaroo Release Vagrant Box.

Promoting a release candidate to a release is a simple process. Run the script with the correct arguments and you are done. The release promotion script is run with the following format:

```bash
bash .release/release.sh RELEASE_CANDIDATE_BRANCH RELEASE_VERSION
```

So, for example, if you are releasing from branch `release-0.4.0`, with version `0.4.0` then your command would be:

```bash
bash .release/release.sh release-0.4.1 0.4.1
```

The script will make changes on the Wallaroo repo it is run in and will prompt you before pushing them back to GitHub.
