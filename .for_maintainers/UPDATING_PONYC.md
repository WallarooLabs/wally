# Updating the Ponyc Version used by Wallaroo

This document is intended to be a checklist for members of the Wallaroo team who may be updating Wallaroo to a newer version of Ponyc. It will outline files that need to be updated

## Files to Update

The following files have a reference to a specific version of Ponyc and will need to be updated as part of upgrading process:

- `.release/bootstrap.sh`: version referenced in the following variable declaration `export PONYC_VERSION=`

- `.travis.yml`: version referenced following the `PONYC_VERSION` declaration under `env: global:`

- `.ci-dockerfiles/ci-standard/Dockerfile`: version referenced following the `ENV` declaration of `PONYC_VERSION`

## Updating the Circle CI Docker Image

After updating the `.ci-dockerfiles/ci-standard/Dockerfile`, you should follow the [README](/.ci-dockerfiles/ci-standard/README.md) to build, test and push the latest Docker image.

Once the CI Docker image has been successfully pushed, you will need to update the tag for all `- image:` declarations that use `wallaroolabs/wallaroo-ci:YYYY.0M.0D.MICRO` to the latest tag in the `YYYY.0M.0D.MICRO` format which you created for the upgraded Ponyc version.

## Files to be Updated at a Later Time

The following files reference a specific Ponyc version but are tied to a specific commit in Wallaroo. Due to this, the Ponyc version should only be updated once the commit in Wallaroo that is referenced is on an updated version of Ponyc.

- `demos/bootstrap.sh`: version referenced in the `apt-get install -y ...` command after `ponyc=`
