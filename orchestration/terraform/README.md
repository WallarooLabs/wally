# Buffy Terraform Orchestration

This module consists of the orchestration for Buffy using Terraform.
So far we have only implemented AWS as a provider.

## Modules

The two modules are `vpc` and `cluster`.

### VPC

The VPC module handles creating the VPC along with the subnet, security group, etc. The state for this is stored in a shared S3 bucket. NOTE: This does *not* guarantee safety for multiple developers to work concurrently (see: https://www.terraform.io/docs/state/remote/).

### Cluster

The cluster module handles creating the actual cluster of nodes and the related AutoScalingGroups, LaunchConfigurations, etc. The state for this is store in a shared S3 bucket. NOTE: This does *not* guarantee safety for multiple developers to work concurrently (see: https://www.terraform.io/docs/state/remote/).

The cluster module depends on the `vpc` module and will fail if the `vpc` module hasn't been created yet.

## Ansible

### General

Once the cluster has been created, you can manage it with Ansible and it's Dynamic Inventory feature (http://docs.ansible.com/ansible/intro_dynamic_inventory.html#example-aws-ec2-external-inventory-script).

* Installing ansible: `pip install ansible`
* Installing boto: `pip install boto`
* Setup ec2.py script: Get the linked `ec2.py` and `ec2.ini` from http://docs.ansible.com/ansible/intro_dynamic_inventory.html#example-aws-ec2-external-inventory-script and save them in the same directory. Make `ec2.py` executable.

Test ansible communication with the all cluster nodes:

`ansible -i ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_buffy' -m ping`

Test ansible communication with the follower nodes only:

`ansible -i ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_buffy:&tag_Role_follower' -m ping`

Test ansible communication with the leader nodes only:

`ansible -i ec2.py --ssh-extra-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" -u ubuntu 'tag_Project_buffy:&tag_Role_leader' -m ping`

### Playbook

There is an ansible playbook for configuring the nodes. It can be run using the following command:

`ansible-playbook --ask-vault-pass -i ../ansible/ec2.py --ssh-common-args="-o StrictHostKeyChecking=no -i PATH_TO_PEM_FILE" ../ansible/playbooks/aws.yml`

