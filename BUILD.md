# BUILDING

## Prerequistes

To build Wallaroo to run on a local development machine, you need to have a working version of the Sendence version of the ponyc compiler installed. (See below). You will also need to install a working copy of the package manager [pony-stable](https://github.com/ponylang/pony-stable).

## Wallaroo

To facilitate builds across environments we are using Make.

To build for your local machine (Wallaroo components and all apps), run:

`make`

This will use your local install of `ponyc`.

To build Wallaroo components only, run   

`make build-buffy-components`  

To build all apps only, run  

`make build-apps`  

All of these must be run from the Wallaroo root directory.  

To build for x86_64 for AWS/Vagrant, run:

`make`

This will use a docker container based `ponyc` to compile for x86_64 based on the Sendence fork of the Pony repository.

The Makefile also supports the following additional build targets:

`make build-docker` - Build docker images for the desired architecture including the compiled binaries.

`make push-docker` - Push docker images for the desired architecture to the repository.

`make help` - Help for options and targets available (ala self-documenting  Makefiles from http://marmelab.com/blog/2016/02/29/auto-documented-makefile.html).

# RELEASING
 
## Pony Projects

### Updating to newer compiler version

By using Pony, we have a development process that differs from many projects. We will sometimes require changes to the Pony compiler and/or Pony standard library. Given that this is a Sendence requirement, we maintain our own fork of Pony at [https://github.com/Sendence/ponyc](https://github.com/Sendence/ponyc). We are currently aiming to get back on mainline Pony and to discontinue our fork. When you encounter such a situation, if you are requesting a new feature/bugfix follow these steps:

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

To update the Sendence Pony repo with the latest code from master in the official Pony repo, follow these steps:

- Get the latest version of the Sendence Pony repo code via cloning or pulling
latest changes.
- Verify that it has an upstream remote set.

```
➜ git remote -v
origin  git@github.com:Sendence/ponyc.git (fetch)
origin  git@github.com:Sendence/ponyc.git (push)
upstream  https://github.com/ponylang/ponyc (fetch)
upstream  https://github.com/ponylang/ponyc (push)
```

If the upstream remote isn't set, add it:

`git remote add upstream https://github.com/ponylang/ponyc`

- Fetch the latest upstream changes: `git fetch upstream`
- Checkout our local master branch: `git checkout master`
- Merge upstream master with ours: `git merge upstream/master`

### Installing Sendence Pony

To install Sendence Pony, use make:

```
make config=release install
```

Make sure that this is the `ponyc` that will be run by default by checking the `ponyc` version, which ends with the first part of the git revision hash (in this case "8ec3e98"):

```
%  ponyc --version
sendence-1.0.0-36-g8ec3e98
% git rev-parse HEAD
8ec3e98227b71f139b3818f88bccd910afd1bafd
```

If you don't see the correct version, you may need to adjust your path.

### Sendence Pony tagging strategy

The Sendence Pony tagging strategy follows [semver](http://semver.org) (with one exception noted below). Our Pony versions have no connection to official Pony versions. Semver works as follows, for software that has the version 1.0.2, it breaks down as follows

1 is the MAJOR version
0 is the MINOR version
2 is the PATCH version

* If a change to the Sendence version of Pony will break existing code, increment the MAJOR version.
* If a change to the Sendence version of Pony will add a new, non breaking feature, increment the MINOR version.
* If the change is related to documentation, increment the PATCH version.
* If the change is from changes requested as part of a pull request process from the Pony team and that change doesn't meet any of the above critera, increment the PATCH version.

All Sendence Pony tags are in the form:

*sendence-MAJOR.MINOR.PATH* 

Do not leave off the leading `sendence-` otherwise we will experience tag
conflicts with the main Pony project (here we depart from the semver guildelines).
