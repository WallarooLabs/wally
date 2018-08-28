# Wallaroo release process

This document is aimed at members of the Wallaroo team who might be cutting a release of Wallaroo. It serves as a checklist that can take your through the release process step-by-step. Releasing is a multi-stage process, as such, this document will refer you to others for those steps.

This document does not cover testing that might need to occur during the release process beyond noting where in the process it should be done.

## Prerequisites

Prior to starting the release process, it is expected that you have successfully provisioned the Wallaroo Vagrant Release box. This process is documented in the [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md) file. Once provisioned, you may continue. It is assumed that you will run all of the release scripts within the Wallaroo Release Vagrant Box.

## Release process overview

Our release process features a few primary steps

* Creation of the release issue (including the checklist for what needs testing, who is testing, dates, etc)
* Creation of the release notes
* Creation of a release candidate branch
* Building and releasing RC artifacts including:
  * Building and releasing the Wallaroo RC source archive and Metrics UI RC AppImage to Bintray
  * Building and releasing the Wallaroo and Metrics UI RC Docker images on Bintray
  * Building and pushing RC Documentation Gitbook
* Testing of the release candidate
* Promoting of a release candidate to a release
* Building and releasing artifacts including:
  * Building and releasing the Wallaroo source archive and Metrics UI AppImage to Bintray
  * Building and releasing the Wallaroo and Metrics UI Docker images on Bintray
  * Building and pushing Documentation Gitbook
* Post release process

- Release issue creation is documented in [RELEASE_ISSUE.md](RELEASE_ISSUE.md)
- Release Notes creation is documented in [RELEASE_NOTES.md](RELEASE_NOTES.md)
- Release candidate branch creation is documented in [RELEASE_CANDIDATE.md](RELEASE_CANDIDATE.md).
- Promoting a release candidate to a release is documented in [RELEASE_PROMOTION.md](RELEASE_PROMOTION.md).
- Building and releasing RC artifacts [UPDATE_RELEASE_ARTIFACTS.md](UPDATE_RELEASE_ARTIFACTS.md).
- Post release process is documented in [POST_RELEASE.md](POST_RELEASE.md).
