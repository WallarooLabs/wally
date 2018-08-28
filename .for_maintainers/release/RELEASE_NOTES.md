# Release Notes Creation

This document is aimed at members of the Wallaroo team who might be cutting a release of Wallaroo. This file should guide you in creating the Release Notes for the upcoming release.

## Release Notes Content

The Release Notes should include a summary of any major user facing additions, changes, or fixes that we want to point out. Additionally, if upgrading is recommended or suggested, upgrading instructions should be included. The last item to be included in the Release Notes is the CHANGELOG. Please have a look at previous Release Notes for examples.


## Release Notes Template

The Release Notes Template is used to create the Release Notes with a specific format based on previous releases. It is a living document and should be updated if any changes to the Release Notes structure occurs. The template can be found [here](RELEASE_NOTES_TEMPLATE.md). The Table of Contents should be updated to reflect what is included in the current release. If a section is not documented, it can be removed for that specific release.

The Upgrading Wallaroo section is mostly complete, if a ponyc upgrade is not needed, that section can be removed. If any other changes need to be made, they should be included. All instances of x.x.x should be updated to refer to the appropriate versions.

The CHANGELOG section should include all changes from the CHANGELOG that is part of the release.

## Release Notes Review

Release Notes should be reviewed by other members of the Wallaroo team to ensure they contain all needed content. The review process should begin during the testing cycle so that the Release Notes do not hold up the release once testing is complete.

## Release Notes Publishing

Publishing the Release Notes is documented in the [POST_RELEASE.md](POST_RELEASE.md) document.
