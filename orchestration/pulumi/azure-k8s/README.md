# Wallaroo Pulumi Orechestration - K8s Cluster module

This module consists of the orchestration for Wallaroo using Pulumi for the K8s Cluster.
So far we have only implemented Azure as a provider.
k8s Cluster creation and tear down are managed via the `orchestration/pulumi` [Makefile](../Makefile).

## Module details

The K8s Cluster module handles creating the K8s Cluster along with the network profile, service principal, etc. The state for this is stored in Pulumi.

The K8s Cluster module's state is used by the `cluster` module.

Files:

* `package.json` defines all the packages required to run
* `Pulumi.yaml` defines all the variable values used by this module
* `index.js` defines all the resources being created using the variables for properties as appropriate

## Info

This currently brings up a single node pool kubernetes cluster and is using the [Pulumi 1.0.0 SDK KubernetesCluster](https://github.com/pulumi/pulumi-azure/blob/v1.0.0/sdk/nodejs/containerservice/kubernetesCluster.ts) derived from the [terraform azurerm_kubernetes_cluster](https://github.com/terraform-providers/terraform-provider-azurerm/blob/0b1449f2eba668775c41f015603b5f20aee36b17/website/docs/r/kubernetes_cluster.html.markdown)


## Installation

Run the following command to install the packages:

```bash
npm install
```

## Pulumi Remote State

We're relying on Pulumi Remote State in order to store state in a centalized location.

The commands available are:

* `pulumi refresh` to refresh the local cache with remote state

See the [Pulumi stack documentation](https://www.pulumi.com/docs/reference/cli/pulumi_stack/) for additional stack commands.
