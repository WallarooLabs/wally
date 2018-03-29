# How to promote a Wallaroo release candidate to a release

This document is aimed at members of the Wallaroo team who might be promoting a Wallaroo release candidate to a release. It serves as a checklist that can take your through the promotion process step-by-step.

To learn more about our release process, see [RELEASE.md].

## Prerequisites for promoting any release candidate to a release

In order to promote a release candidate to a release, you absolutely must have:

* Commit access to the `wallaroo` repo
* Commit access to the `wallaroo` `release` branch
* Installed the [changelog tool](https://github.com/ponylang/changelog-tool)

## Prerequisites for specific release candidate to release promotion

Before getting started, you will need the number for the version that you will be releasing and the release candidate branch. Before continuing ensure the following of the release candidate branch:

* Includes the updated version for the upcoming release in the VERSION file
* It passed all CI checks on the latest commit

## Promoting a release candidate to a release

Please note that the release script was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo.

Promoting a release candidate to a release is a simple process. Run a script with the correct arguments and you are done. The release promotion script is run as:

```bash
bash .release/rp.sh RELEASE_CANDIDATE_BRANCH RELEASE_VERSION
```

So, for example, if you are releasing from branch `release-0.4.0`, with version `0.4.0` then your command would be:

```bash
bash .release/rp.sh release-0.4.1 0.4.1
```

The script will make changes on in your local Wallaroo repo and will prompt you before pushing them back to GitHub.
