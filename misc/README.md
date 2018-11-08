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

It takes two optional positional arguments. Arg1 is which language's examples to test (go/python/pony) and Arg2 is which example to test (alerts_stateless/etc). By default, it will run examples for all languages.

NOTE: This has only been tested on Linux. It may or may not work on OSX/other environments.

## Wallaroo Up tester

The Wallaroo Up tester is a script to automate running Wallaroo Up and all example applications for every distribution supported by Wallaroo Up. It does so by looping through a list of supported distributions and then using either Vagrant or Docker to start the appropriate environment for running Wallaroo Up and the Wallaroo example tester.

The Wallaroo Up tester requires an environment with Docker and/or Vagrant/Virtualbox installed and available with Docker set up to be run without `sudo`. Vagrant also requires the `vagrant-vbguest` plugin to be install. It can be installed via the following command:

```
vagrant plugin install vagrant-vbguest
```

You can run the Wallaroo Up tester on any Wallaroo source tree via the following command:

```
./wallaroo-up-tester.bash
```

It takes four optional positional arguments. Arg1 is maximum number of environments to test in parallel. Arg2 is whether to test a `custom` or the latest `released` set of artifacts. If custom, it will use the current source tree to generate the appropriate artifacts to use. Arg3 is which environment to test in (docker/vagrant/all). Arg4 is which distribution to test (xenial/etc). By default, it will run Wallaroo Up and the example tester for all distributions in all environments with the latest released artifacts.

NOTE: This has only been tested on Linux and OSX. It may or may not work on other environments.

### Known issues

The parallel output to screen is not easy to follow as it is all interleaved across all parallel invocations of `wallaroo-up.sh` and `example-tester.bash`. In order to see output for a specific distro/environment, it is recommended to either run with parallelism=1 or to look at the logs for each distro/environment manually.

Using `ctrl-c` (or kill or similar) to break the `wallaroo-up-tester.bash` script does **NOT** result in any `vagrant` instances it creates being destroyed. It is possible to handle this via a trap and some logic in the script but the functionality has not been implemented.

This means that if you do break the script, the errant vagrant VMs will have to be manually cleaned up.

### Testing in AWS

You will need to use an `i3.metal` instance type and you will need `docker`, `vagrant`, and `virtualbox` installed.

Once you have an `i3.metal` instance with the requisite software installed and a copy of the wallaroo source tree, you can run the following to run the `wallaroo-up-tester` in parallel (the commands assume you are in `<wallaroo_root>/misc`):

```bash
./wallaroo-up-tester.bash 72
```

#### Known issues

There is a known issue with AWS and `fedora` Vagrant images. For some reason, the Vagrant box file download results in a `404` error. See https://github.com/WallarooLabs/wallaroo/issues/2591 for details. This same issue does not occur when the same vagrant boxes are used via the same commands on a MacOS laptop.

### Testing Python examples with `machida3`

You need to search/replace `machida` with `machida3` in `<wallaroo_root>/examples/python/*/README.md`.

Once that is completed, you can run the following to run the `wallaroo-up-tester` to use a custom copy of the wallaroo source tree with all the search/replace changes (the commands assume you are in `<wallaroo_root>/misc`):


```bash
./wallaroo-up-tester.bash 1 custom
```
