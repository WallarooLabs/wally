# Wallaroo Up and release/example testing

## Wallaroo Up

Wallaroo Up is a script to automate the from source installation/configuration of a Wallaroo development environment for Linix environments.

Run the following for help on arguments:

```
./wallaroo-up.sh -h
```

## Wallaroo example tester

The example tester is a script to automate running example applications. It does so by parsing the `README.md` for each example and then executing the command we're directing users to execute. It does not check for correct output but only that the commands do not exit with errors.

You can run the example tester on any Wallaroo source tree via the following command:

```
./example-tester.bash
```

It takes two optional positional arguments. Arg1 is which language's examples to test (go/python/pony) and Arg2 is which example to test (celsius/etc). By default, it will run examples for all languages.

NOTE: This has only been tested on Linux. It may or may not work on OSX/other environments.

## Wallaroo release tester

The release tester is a script to automate running Wallaroo Up and all example applications for every distribution supported by Wallaroo Up. It does so by looping through a list of supported distributions and then using either Vagrant or Docker to start the appropriate environment for running Wallaroo Up and the Wallaroo example tester.

The release tester requires an environment with Docker and/or Vagrant/Virtualbox installed and available with Docker set up to be run without `sudo`. Vagrant also requires the `vagrant-vbguest` plugin to be install. It can be installed via the following command:

```
vagrant plugin install vagrant-vbguest
```

You can run the release tester on any Wallaroo source tree via the following command:

```
./release-tester.bash
```

It takes three optional positional arguments. Arg1 is whether to test a `custom` or the latest `released` set of artifacts. If custom, it will use the current source tree to generate the appropriate artifacts to use. Arg2 is which environment to test in (docker/vagrant/all). Arg3 is which distribution to test (xenial/etc). By default, it will run Wallaroo Up and the example tester for all distributions in all environments with the latest released artifacts.

NOTE: This has only been tested on Linux and OSX. It may or may not work on other environments.
