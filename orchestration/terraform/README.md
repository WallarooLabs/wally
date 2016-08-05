# Buffy Terraform Orchestration

This module consists of the orchestration for Buffy using Terraform.
So far we have only implemented AWS as a provider.

## Modules

The two modules are `vpc` and `cluster`.

### VPC

The VPC module handles creating the VPC along with the subnet, security group,
etc. The state for this is stored in a shared S3 bucket.

NOTE: This does *not* guarantee safety for multiple developers to work
concurrently (see: https://www.terraform.io/docs/state/remote/).

### Cluster

The cluster module handles creating the actual cluster of nodes and the related
AutoScalingGroups, LaunchConfigurations, etc. The state for this is store in a
shared S3 bucket. 

NOTE: This does *not* guarantee safety for multiple developers to work
concurrently (see: https://www.terraform.io/docs/state/remote/). See section for
`Makefile` for a safe multi-developer workflow.

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

NOTE: The `Makefile` uses a password file for Ansible Vault when configuring
the cluster. The default password file is `~/.ansible_vault_pass.txt` and 
the command will fail if the file doesn't exist. The command will also fail
if the file contents are not the correct Vault password. If you need to know
the Vault password in order to create the password file, please ask Dipin 
or Sean or Markus.

NOTE: The `Makefile` does *not* currently ensure that the lock is released if
there is an error running any commands after acquiring the lock.

### Automagic Instance logic

The `Makefile` uses a python script to automagically figure out the
appropriate instance available that will meet the requirements. The way it
works is the python script outputs a `Makefile` fragment which is then
`eval`'d by make.

This automagic instance logic can be controlled via the following
`make` option:

* `use_automagic_instances`  Find appropriate instances to use (spot included);
  Will automagically use placement groups if applicable (Default: true)

The inputs into this script are the following `make` options:

* `region` Region to launch cluster in. (Default: us-east-1)
* `availability_zone` Availability Zone to launch cluster in. (Default: )
* `mem_required` Minimum amount of memory in GB per instance (Default: 0.5)
* `cpus_required` Minimum amount of CPUs per instance (Default: 0.05)

The script uses the following logic to find cheapest prices:

* Look up on-demand instances (current and previoud generation) for the region
* Filter on-demand instance list based on `mem_required` and `cpus_required`
  to identify valid instances
* Look up current spot prices for all the valid instances. If no
  `availability_zone` specifid, look across all availability zones. Otherwise,
  only look in specified availability zone.
* Look through current spot prices to determine cheapest one.
* Look through valid instances on-demand prices to see if there's an
  on-demend instance that is cheaper than spot pricing.
* If the cheapest instance is allowed to be in a placement group, prepare
  the placement group related output.
* If the cheapest instance is an on-demand instance, output the appropriate
  `*_instance_type` variables for terraform along with the placement group
  output if needed.
* If the cheapest instance is a spot instance, output the appropriate
  `*_instance_type` and `*_spot_price` variables for terraform along with
  the placement group output if needed. Also output the `availability_zone`
  for the spot instance (this will be the same as what the user requested
  or the one for the best spot pricing based on the logic described above).

### Examples

The following examples are to illustrate the features available and common use
cases (unless `use_automagic_instances=false` is used, it will automagically
figure out the appropriate instance available for use based on `mem_required`
[defaults to 0.5 GB] and `cpus_required` [defaults to 0.05 for t2.nano level
of CPU] values):

* Detailed options/targets/help:
  `make help`
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
* Create a cluster using spot pricing and m3.medium instances (and not using 
  automagic instance logic):
  `make apply use_automagic_instances=false terraform_args="-var leader_spot_price=0.02 -var follower_spot_price=0.02 -var leader_instance_type=m3.medium -var follower_instance_type=m3.medium" cluster_name=example`
* Create a cluster using placement group and m4.large instances (and not
  using automagic instance logic):
  `make apply use_automagic_instances=false use_placement_group=true terraform_args="-var leader_instance_type=m4.large -var follower_instance_type=m4.large" cluster_name=example`
* Create a cluster using placement group and m4.xlarge instances and spot pricing
  (and not using automagic instance logic):
  `make apply use_automagic_instances=false use_placement_group=true terraform_args="-var leader_spot_price=0.05 -var follower_spot_price=0.05 -var leader_instance_type=m4.large -var follower_instance_type=m4.large" cluster_name=example`
* Create and configure (with ansible) a cluster with name `sample`:
  `make cluster cluster_name=sample`
* Create and configure (with ansible) a cluster with name `sample` in region
  `us-east-1`:
  `make cluster cluster_name=sample region=us-east-1`
* Create and configure (with ansible) a cluster with name `sample` in region
  `us-east-1` and availabiilty zone `us-east-1a`:
  `make cluster cluster_name=sample region=us-east-1 availability_zone=us-east-1a`
* Create and configure (with ansible) a cluster with name `example` where
  the instances have at least 8 cpus and 16 GB of RAM:
  `make cluster mem_required=16 cpus_required=8 cluster_name=example`
* Create and configure (with ansible) a cluster with name `example` where
  the instances have at least 8 cpus and 16 GB of RAM and don't use spot pricing:
  `make cluster mem_required=16 cpus_required=8 no_spot=true cluster_name=example`

