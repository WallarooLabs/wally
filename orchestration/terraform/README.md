# Buffy Terraform Orchestration

This module consists of the orchestration for Buffy using Terraform.
So far we have only implemented AWS as a provider.

## Modules

The two modules are `vpc` and `cluster`.

### VPC

The VPC module handles creating the VPC along with the subnet, security group, etc.
The state for this is stored in a shared S3 bucket.

NOTE: This does *not* guarantee safety for multiple developers to work concurrently
(see: https://www.terraform.io/docs/state/remote/).

### Cluster

The cluster module handles creating the actual cluster of nodes and the related
AutoScalingGroups, LaunchConfigurations, etc. The state for this is store in a
shared S3 bucket. 

NOTE: This does *not* guarantee safety for multiple developers to work concurrently
(see: https://www.terraform.io/docs/state/remote/). See section for `Makefile` for
a safe multi-developer workflow.

The cluster module depends on the `vpc` module and will fail if the `vpc` module
hasn't been created yet.

## Ansible

### General

Once the cluster has been created, you can manage it with Ansible and its Dynamic 
Inventory feature (http://docs.ansible.com/ansible/intro_dynamic_inventory.html#example-aws-ec2-external-inventory-script).

* Installing ansible: `pip install ansible`
* Installing boto: `pip install boto`
* Setup ec2.py script: Get the linked `ec2.py` and `ec2.ini` from 
http://docs.ansible.com/ansible/intro_dynamic_inventory.html#example-aws-ec2-external-inventory-script
and save them in the same directory. Make `ec2.py` executable.

Test ansible communication with the all cluster nodes:

`ansible -i ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_buffy' -m ping`

Test ansible communication with the follower nodes only:

`ansible -i ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_buffy:&tag_Role_follower' -m ping`

Test ansible communication with the leader nodes only:

`ansible -i ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_buffy:&tag_Role_leader' -m ping`

### Playbook

There is an ansible playbook for configuring the nodes. It can be run using the
following command:

`ansible-playbook --ask-vault-pass -i ../ansible/ec2.py --ssh-common-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu --extra-vars "cluster_name=<NAME_OF_CLUSTER>" ../ansible/playbooks/aws.yml`

## Makefile

It is recommended that `make` be used to manage the AWS clusters (including
running Ansible) for a safe workflow for concurrent use by multiple developers.

Command/options can be identified by running: `make help`

The `Makefile` enforces the following:

* Acquire lock from simpledb if the lock is free or if it was previously
  acquired by the current user and not properly released
* Reset terraform state file (based on cluster name) from S3 or initialize if
  new
* Make sure VPC is created
* Run terraform plan/apply/destroy command
* Release lock from simpledb if it is held by the current user (throw error
  otherwise)

NOTE: The `Makefile` does *not* currently ensure that the lock is released if
there is an error running any commands after acquiring the lock.

### Examples

The following examples are to illustrate the features available and common use cases:

* Plan a new cluster with name `sample`:
  `make plan cluster_name=sample`
* Create a new cluster with name `sample`:
  `make apply cluster_name=sample`
* Configure (with ansible) a cluster with name `sample`:
  `make configure cluster_name=sample`
* Configure (with ansible) a cluster with name `sample` using a custom pem file:
  `make configure cluster_name=sample cluster_pem=/path/to/custom/pem/file`
* Plan a new cluster with name `sample` with extra terraform arguments
  (`--version` in this case but could be anything):
  `make plan cluster_name=sample terraform_args="--version"`
* Destroy a cluster with name `sample`:
  `make destroy cluster_name=sample`

