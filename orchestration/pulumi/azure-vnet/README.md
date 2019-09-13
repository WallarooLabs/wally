# Wallaroo Pulumi Orechestration - VNet module

This module consists of the orchestration for Wallaroo using Pulumi for the VNet.
So far we have only implemented Azure as a provider.

## Module details

The VNet module handles creating the VNet along with the subnet, network security group, etc. The state for this is stored in Pulumi.

The VNet module's state is used by the `cluster` module.

Files:

* `package.json` defines all the packages required to run
* `Pulumi.yaml` defines all the variable values used by this module
* `index.js` defines all the resources being created using the variables for properties as appropriate

## Pulumi Remote State

We're relying on Pulumi Remote State in order to store state in a centalized location.

The commands available are:

* `pulumi refresh` to refresh the local cache with remote state

Documentation for additional stack commands can be found at: https://www.pulumi.com/docs/reference/cli/pulumi_stack/

