# Ansible for Buffy Orchestration

This module consists of Ansible playbooks and roles for Buffy Orchestration for
the different targets.

The following are the currently supported targets:

* Vagrant
* AWS
* Hypriot on RPi

## Vault

The Ansible playbooks all use Ansible Vault to encrypt sensitive information.
At the moment the only sensitive information we have is the login/password for
the private Sendence docker repository. Because of this, all the Ansible
playbook examples prompt for a password on execution. This can (and likely will)
be changed so the password can be read from a file instead so as to not require
user input.

## Vagrant

Please look at the documentation in the 
[Vagrant orchestration section](../vagrant/README.md) for examples on how to use
Ansible to configure the vagrant nodes.

## AWS

Please look at the documentation in the 
[Terraform orchestration section](../terraform/README.md) for examples on how to
use Ansible to configure the AWS nodes.

## Hypriot on RPi

Please look at the documentation in the
[RaspberryPi orchestration section](../raspberrypi/README.md) for examples on 
how to use Ansible to configure the RPi nodes.

