# RELEASING
 
## Pony Projects

### Updating to newer compiler version

By using Pony, we have a development process that differs from many projects. We
will sometimes  require changes to the Pony compiler and/or Pony standard
library. Given that this is a Sendence requirement, we maintain our own fork of
Pony at [https://github.com/Sendence/ponyc](https://github.com/Sendence/ponyc).
When you encounter such a situation, if you are requesting a new feature/bugfix
follow these steps:

- Request a new feature/bugfix
- Update the Sendence Pony fork with required changes from main pony repo
- Test that all code compiles with new version
- Tag new Sendence Pony version and push
- Inform everyone via #standup and #b-general slack channel of the change
- Update our build files to use the new version
- Merge those changes to master on the Buffy repo
- Build / test everything again

If you are doing the work yourself

- Implement new feature/fix in Sendence Pony fork.
- Test all our code compiles with new version
- Tag new Sendence Pony version and push
- Inform everyone via #standup and #b-general slack channel of the change
- Update our build files to use the new version
- Push any corresponding/dependent Buffy changes
- Open a Pull Request against main Pony repo.
- Make any changes to your feature as requested by Pony team
- Retag Sendence Pony after your feature is accepted and push
- Inform everyone via #standup and #b-general slack channel of the change
- Update our build files to use the new version
- Build / test everything again

### Sync Sendence Pony with official Pony repo

To update to Sendence Pony repo with the latest code from master in the official
Pony repo, follow these steps:

- Get the latest version of the Sendence Pony repo code via cloning or pulling
latest changes.
- Verify that it has an upstream remote set.

```
➜ git remote -v
origin  git@github.com:Sendence/ponyc.git (fetch)
origin  git@github.com:Sendence/ponyc.git (push)
upstream  https://github.com/CausalityLtd/ponyc (fetch)
upstream  https://github.com/CausalityLtd/ponyc (push)
```

If the upstream remote isn't set, add it:

`git remote add upstream https://github.com/CausalityLtd/ponyc`

- Fetch the latest upstream changes: `git fetch upstream`
- Checkout our local master branch: `git checkout master`
- Merge upstream master with ours: `git merge upstream/master`

### Sendence Pony tagging strategy

The Sendence Pony tagging strategy follows [semvar](http://semver.org). Our Pony
version have no connection to official Pony versions. Semvar works as follows,
for software that has the version 1.0.2, it breaks down as follows

1 is the MAJOR version
0 is the MINOR version
2 is the PATCH version

* If a change to the Sendence version of Pony will break existing code,
increment
the MAJOR version.
* If a change to the Sendence version of Pony will add a new, non breaking
feature, increment the MINOR version.
* If the change is related to documentation, increment the PATCH version.
* If the change is from changes requested as part of a pull request process from
the Pony team and that change doesn't meet any of the above critera, increment
the PATCH version.

All Sendence Pony tags are in the form:

*sendence-MAJOR.MINOR.PATH* 

Do not leave off the leading `sendence-` otherwise we will experience tag
conflicts with the main Pony project.
