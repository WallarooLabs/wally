# Wallaroo Terraform Orchestration

This module consists of the orchestration for Wallaroo using Terraform.
So far we have only implemented AWS and Packet as the providers.

## Modules

The three modules are `aws-vpc`, `aws-cluster` and `packet-cluster`.

### AWS-VPC

The VPC module handles creating the VPC along with the subnet, security group,
etc. The state for this is stored in a shared S3 bucket.

NOTE: This does *not* guarantee safety for multiple developers to work
concurrently (see: https://www.terraform.io/docs/state/remote/).

### AWS-Cluster

The AWS cluster module handles creating the actual cluster of nodes in EC2 and the related
AutoScalingGroups, LaunchConfigurations, etc. The state for this is store in a
shared S3 bucket. 

NOTE: This does *not* guarantee safety for multiple developers to work
concurrently (see: https://www.terraform.io/docs/state/remote/). See section for
`Makefile` for a safe multi-developer workflow.

The cluster module depends on the `aws-vpc` module and will fail if the `aws-vpc` module
hasn't been created yet.

### Packet-Cluster

The Packet cluster module handles creating the actual cluster of nodes in Packet.net.
The state for this is store in a shared S3 bucket. 

NOTE: This does *not* guarantee safety for multiple developers to work
concurrently (see: https://www.terraform.io/docs/state/remote/). See section for
`Makefile` for a safe multi-developer workflow.

## Configuration

### General

Software needed:

* aws cli
* git
* make
* python
* pip
* sed
* awk
* tr
* grep
* egrep
* curl
* sort
* wc
* head
* tail
* jq
* terraform (need version `0.7.4`). Get the exact version here: https://releases.hashicorp.com/terraform/
* Installing ansible (need version `ansible-2.1.1.0`): `pip install 'ansible==2.1.1.0' --force-reinstall`
* Installing boto: `pip install boto`
* Installing packet: `pip install packet-python`

Accounts needed:

* AWS Console (ask Dipin or Sean)
* Packet.net Console (ask Dipin)

Configuration needed:

* Create AWS config using `aws configure` command
* Set up shared ssh keys in `~/.ssh/ec2/` (ask Dipin or someone else for where to get the
  key files)
* Create Packet.net account based on invitation to project and generate API key
* Create `~/.terraform_packet_vars` with the following format including Packet project id
  (use the one specified here) and API token:
```
packet_api_key = "<PACKET API KEY FROM WEBSITE>"
packet_project_id = "3d35c26a-5d26-4188-bb70-c648410919c1"
```


## Makefile

It is recommended that `make` be used to manage the AWS clusters (including
running Ansible) for a safe workflow for concurrent use by multiple developers.

NOTE: Command/options can be identified by running: `make help`

The `Makefile` enforces the following:

* Acquire lock from simpledb if the lock is free or if it was previously
  acquired by the current user and not properly released
* Reset terraform state file (based on cluster name) from S3 or initialize if
  new
* Make sure VPC is created (if required)
* Run terraform plan/apply/destroy command
* Release lock from simpledb if it is held by the current user (throw error
  otherwise)

NOTE: The `Makefile` does *not* currently ensure that the lock is released if
there is an error running any commands after acquiring the lock.

### Automagic Instance logic

The `Makefile` uses a python script to automagically figure out the
appropriate instance available that will meet the requirements for AWS clusters.
The way it works is the python script outputs a `Makefile` fragment which is then
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
* `force_instance` The instance type to use for all nodes (Default: )

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

### AWS Examples

The following examples are to illustrate the features available and common use
cases for the AWS provider (unless `use_automagic_instances=false` is used, it
will automagically figure out the appropriate instance available for use based
on `mem_required` [defaults to 0.5 GB] and `cpus_required` [defaults to 0.05 
for t2.nano level of CPU] values):

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
* Check ptpd offset for all followers in a cluster with name `sample`:
  `make check-ptpd-offsets cluster_name=sample`

### Packet Examples

The following examples are to illustrate the features available and common use
cases for the Packet provider.

* Detailed options/targets/help:
  `make help`
* Plan a new cluster with name `sample` using Packet:
  `make plan cluster_name=sample provider=packet use_automagic_instances=false`
* Create a new cluster with name `sample`:
  `make apply cluster_name=sample provider=packet use_automagic_instances=false`
* Configure (with ansible) a cluster with name `sample`:
  `make configure cluster_name=sample provider=packet use_automagic_instances=false`
* Plan a new cluster with name `sample` with extra terraform arguments
  (`--version` in this case but could be anything):
  `make plan cluster_name=sample provider=packet use_automagic_instances=false terraform_args="--version"`
* Destroy a cluster with name `sample`:
  `make destroy cluster_name=sample provider=packet use_automagic_instances=false`
* Check ptpd offset for all followers in a cluster with name `sample`:
  `make check-ptpd-offsets cluster_name=sample`

## Debugging Ansible for AWS

Test ansible communication with the all cluster nodes:

`ansible -i ../ansible/ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_wallaroo' -m ping`

Test ansible communication with the follower nodes only:

`ansible -i ../ansible/ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_wallaroo:&tag_Role_follower' -m ping`

Test ansible communication with the leader nodes only:

`ansible -i ../ansible/ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_wallaroo:&tag_Role_leader' -m ping`


## Debugging Ansible for Packet

Test ansible communication with the all cluster nodes:

`ansible -i ../ansible/packet_net.py --ssh-extra-args="-o StrictHostKeyChecking=no -i ~/.ssh/ec2/us-east-1.pem" -u root 'tag_wallaroo' -m ping`

Test ansible communication with the follower nodes only:

`ansible -i ../ansible/packet_net.py --ssh-extra-args="-o StrictHostKeyChecking=no -i ~/.ssh/ec2/us-east-1.pem" -u root 'tag_wallaroo:&tag_Role_follower' -m ping`

Test ansible communication with the leader nodes only:

`ansible -i ../ansible/packet_net.py --ssh-extra-args="-o StrictHostKeyChecking=no -i ~/.ssh/ec2/us-east-1.pem" -u root 'tag_Project_wallaroo:&tag_Role_leader' -m ping`

## Manually cleaning up AWS resources

If for some reason the `make destroy` command isn't working correctly and deleting the AWS resources previously created, you can manually clean things up instead.
NOTE: You shouldn't have to do this unless `make destroy` repeatedly fails as it is safe to run multiple times until it succeeds.

Go into `AWS Console (Web UI) -> EC2 -> Auto Scaling Groups` and find/delete the entries related to your cluster (the cluster_name is at the beginning of the resource name).

Go into `AWS Console (Web UI) -> EC2 -> Launch Configurations` and find/delete the entries related to your cluster (the cluster_name is at the beginning of the resource name).

Go into `AWS Console (Web UI) -> EC2 -> Placement Groups` and find/delete the entry related to your cluster (the cluster_name is at the end of the resource name with a format of `wallaroo-<CLUSTER_NAME>`).

## Major recovery

If `make destroy` and `make cluster` are both failing for a cluster and it's in some sort of invalid state where terraform state file doesn't match up with AWS reality any more.

Run the following to completely remove the terraform state:

`make force-delete-cluster-state` ## WARNING: It is very important to run this command passing in all the normal arguments you would normally pass when creating a cluster as those arguments are used to determine which state file needs to be deleted.

NOTE: You will have to manually clean up any lingering resources after this but it should resolve the issues with the make command not working.
