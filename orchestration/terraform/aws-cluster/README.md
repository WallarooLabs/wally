# Wallaroo Terraform Orechestration - Cluster module

This module consists of the orchestration for Wallaroo using Terraform for the actual cluster nodes.
So far we have only implemented AWS as a provider.

## Module details

The cluster module handles creating the actual cluster of nodes and the related AutoScalingGroups, LaunchConfigurations, etc. The state for this is store in a shared S3 bucket. NOTE:
This does *not* guarantee safety for multiple developers to work concurrently (see: https://www.terraform.io/docs/state/remote/).

The cluster module depends on the `vpc` module and will fail if the `vpc` module hasn't been created yet.

Files:

* `variables.tf` defines all the variables being used and their defaults
* `outputs.tf` defines all the output values we expose for use by modules that depends on this one
* `cluster.tf` defines all the resources being created using the variables for properties as appropriate
* `follower_user_data.sh` is the user-data script to use on follower nodes
* `leader_user_data.sh` is the user-data script to use on leader nodes

## Terraform Remote State

We're relying ton Terraform Remote State in order to store state in a centalized location.

The commands available are:

* `terraform remote pull` to refresh the local cache with remote state
* `terraform remote push` to sync the local cache with remote state
* `terraform remote config` to configure/change configuration for the remote state

Documentation can be found at: https://www.terraform.io/docs/commands/remote.html

NOTE: So far it doesn't seem like it is necessary to use the pull/push commands explicitly the majority of the time as Terraform seems to automagically do a pull/push as required (except when a `terraform show` command is used).

