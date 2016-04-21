# Continuous Integration

Buffy is built on every commit in a build server for amd64 and armhf targets.

We are currently using Drone CI as our build server which can be accessed at
[Sendence Drone server](https://drone.sendence.com). If you're unable to log in,
please contact Dipin or Sean and they can add your GitHub user account to the
list of authorized users.

Documentation for Drone CI can be found at 
[Drone CI docs](http://readme.drone.io/).

## Projects

Drone CI handles builds for Sendence/Buffy and Sendence/ponyc repositories.

For Sendence/ponyc, it will build for each commit to master and for any new tags
created.

For Sendence/Buffy, it will build for each commit to master and for any new 
tags.

For Sendence/Buffy, it will also do a nightly build based on a nightly_ponyc
branch which nobody should commit to except to update the build instructions.
The build for this branch pulls the latest ponylang/ponyc master, compiles it
for use and then pulls the latest Sendence/Buffy master, compiles it using the
new ponyc build and then runs tests for it.

Both projects are configured to send build status notifications to the 
`#b-drone-ci` channel on slack.

## Configuration

In order to enable a project for Drone CI builds two items need to be completed:

* Add a .drone.yml file at the root of the project directory
* Activate the repository in the Drone UI

Documentation for the .drone.yml format and sections can be found on the Drone
documentation webiste mentioned earlier.

## Local builds

Drone has a cli tool that can be used for local builds that are very close to
(but not 100% the same as) the Drone CI server builds.

Details can be found at: 
http://readme.drone.io/devs/cli/#local-testing:b659b046131d4024ab5e2d3675716bf0

