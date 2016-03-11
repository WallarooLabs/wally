# Buffy Vagrant Orechestration

This module consists of the orchestration for Buffy using Vagrant.
So far we have only implemented Virtualbox as a provider.

## Provisioning

Run `vagrant up` to create the nodes (1 leader and 2 followers by default). Change `LEADER_COUNT` and `FOLLOWER_COUNT` at top of `Vagrantfile` for different numbers of nodes.

## Ansible

### General

Once the cluster has been created, you can manage it with Ansible and it's Dynamic Inventory feature (http://docs.ansible.com/ansible/intro_dynamic_inventory.html).

* Installing ansible: `pip install ansible`

Test ansible communication with the all cluster nodes:

`ansible -i ../ansible/vagrant.py --ssh-extra-args="-o StrictHostKeyChecking=no" all -m ping`

Test ansible communication with the follower nodes only:

`ansible -i ../ansible/vagrant.py --ssh-extra-args="-o StrictHostKeyChecking=no" 'buffy-follower*' -m ping`

Test ansible communication with the leader nodes only:

`ansible -i ../ansible/vagrant.py --ssh-extra-args="-o StrictHostKeyChecking=no" 'buffy-leader*' -m ping`

### Playbook

There is an ansible playbook for configuring the nodes. It can be run using the following command:

`ansible-playbook --ask-vault-pass -i ../ansible/vagrant.py --ssh-common-args="-o StrictHostKeyChecking=no" ../ansible/playbooks/vagrant.yml`

