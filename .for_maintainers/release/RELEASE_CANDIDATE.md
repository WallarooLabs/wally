# How to create a Wallaroo release candidate

This document is aimed at members of the Wallaroo team who might be creating a Wallaroo release candidate. It serves as a checklist that can take your through the creation process step-by-step.

To learn more about our release process, see [RELEASE.md].

## Prerequisites for creating any release candidate

In order to do a release candidate, you absolutely must have:

* Commit access to the `wallaroo` repo

## Prerequisites for specific release candidate

Before getting started, you will need a number for the version that you will be releasing as well as an agreed upon "golden commit" that will form the basis of the release.  Any commit is eligible to be a "golden commit" so long as:

* It's on `master`
* It passed all CI checks

## Cutting a release candidate

Please note that the release script was written with the assumption that you are using a clone of the `wallaroolabs/wallaroo` repo. This process will not work without modification if you try to use a fork rather than a clone of the repo.

Cutting a release candidate is a simple process. Run a script with the correct arguments and you are done. The release candidate script is run as:

```bash
bash .release/rc.sh MY_VERSION MY_GOLDEN_COMMIT
```

So, for example, if you are releasing version `0.4.0` from golden commit `8a8ee28` then your command would be:

```bash
bash .release/rc.sh 0.4.0 8a8ee28
```

The script will make changes on in your local Wallaroo repo and will prompt you before pushing them back to GitHub.
