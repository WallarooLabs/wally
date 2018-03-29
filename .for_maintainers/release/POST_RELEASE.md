# Post release process for Wallaroo

This document is aimed at members of the Wallaroo team who might be completing the Wallaroo release process. It serves as a checklist that can take your through the post release process step-by-step.

To learn more about our release process, see [RELEASE.md].

## Drafting a new Github Release

Visit the [wallaroo releases](https://github.com/WallarooLabs/wallaroo/releases) page and click on the `Draft a New Release` button.

There will be a text field with `Tag version` as a place holder. You will need to enter the tag of the release you pushed. So if you just pushed tag `0.4.0` as part of the release, you'll enter `0.4.0` and the `Target` branch will be `release`.

The `Release Title` will be the same as the tag and version you just pushed. If it was `0.4.0` you'd enter `0.4.0`.

For the content of the release, you'd enter `Release Notes` as a h1 header and include the changes within the `CHANGELOG` for this release. Dependent on what it is included, you might want to preface with a few words. Have a look at previous releases for ideas.

Once you have completed the above, click on the `Publish release` button in order to publish the release.

## Merging `release` into `master`

After the release has been published, you'll want to do the following in the Wallaroo repo:

### Checkout to `master`

```bash
git checkout master
git pull
```

### Merge the `release` branch

```bash
git merge origin/release
```

### Resolving CHANGELOG Conflicts

You may run into conflicts with the `CHANGELOG` when merging. You'd want to ensure any item under `Unreleased` is not part of the release you just published.

If the `Unreleased` section is missing, it can be added using the [changelog tool](https://github.com/ponylang/changelog-tool), like so:

```bash
changelog-tool unreleased CHANGELOG.md -e
```
## Pushing to `master`

Once you have successfully merged the `release` branch into `master` you will have to push:

```bash
git push origin master
```
