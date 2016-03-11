# Ansible for Buffy Orchestration

This module consists of Ansible playbooks and roles for Buffy Orchestration for the different targets.

The following are the currently supported targets:

* Vagrant
* AWS
* Hypriot on RPi

## Vault

The Ansible playbooks all use Ansible Vault to encrypt sensitive information. At the moment the only sensitive information we have is the login/password for the private Sendence docker repository. Because of this, all the Ansible playbook examples prompt for a password on execution. This can (and likely will) be changed so the password can be read from a file instead so as to not require user input.

## Vagrant

Please look at the documentation in the [Vagrant orchestration section](../vagrant/README.md) for examples on how to use Ansible to configure the vagrant nodes.

## AWS

Please look at the documentation in the [Terraform orchestration section](../terraform/README.md) for examples on how to use Ansible to configure the AWS nodes.

## Hypriot on RPi

In order to configure the Hypriot nodes you need to do the following...

### Hosts file

Create a `hosts` file with the following format identifying all leader/follower nodes:

```
[buffy-leaders]
<LEADER_IP_HOSTNAME>
<LEADER_IP_HOSTNAME>

[buffy-followers]
<FOLLOWER_IP_HOSTNAME>
<FOLLOWER_IP_HOSTNAME>

```

### Copy ssh key to nodes

Use the following to copy a ssh key to every node for passwordless authentication:

`ssh-copy-id -i <PATH/TO/PUBLIC/KEY> root@<IP_HOSTNAME>`

### Test Ansible connection to nodes

Test your Ansible connection to the nodes by running:

`ansible all -i hosts --ssh-extra-args="-o StrictHostKeyChecking=no -i <PATH/TO/PUBLIC/KEY>" -u root -m ping`

If you're able to successfully connect and Python is installed already you will see:

```
<NODE_IP_HOSTNAME> | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

If you're able to successfully connect and Python is not installed already you will see:

```
<NODE_IP_HOSTNAME> | FAILED! => {
    "changed": false, 
    "failed": true, 
    "module_stderr": "", 
    "module_stdout": "bash: /usr/bin/python: No such file or directory\r\n", 
    "msg": "MODULE FAILURE", 
    "parsed": false
}
```

Both of these are good/acceptable results because they both confirm that Ansible is able to successfully use passwordless ssh to authenticate with the nodes.

### Run Ansible playbook to configure nodes

Now that you're successfully able to connect to the nodes, you can run the Ansible playbook to configure them:

`ansible-playbook --ask-vault-pass -i hosts --ssh-extra-args="-o StrictHostKeyChecking=no -i <PATH/TO/PUBLIC/KEY>" -u root playbooks/hypriot.yml`

Assuming no errors you'll see something like the following at the end of the output:

```
PLAY RECAP *********************************************************************
<FOLLOWER_IP_HOSTNAME>      : ok=36   changed=19   unreachable=0    failed=0   
<LEADER_IP_HOSTNAME>        : ok=36   changed=19   unreachable=0    failed=0   
```

In case of error you'll see:

```
TASK [<ROLE_NAME> : <TASK NAME>] **************************************
fatal: [<NODE_IP_HOSTNAME>]: FAILED! => {"changed": false, "cmd": "<COMMAND EXECUTED>", "failed": true, "msg": "<ERROR OUTPUT LOG>"}

PLAY RECAP *********************************************************************
<FOLLOWER_IP_HOSTNAME>      : ok=8    changed=2    unreachable=0    failed=0   
<LEADER_IP_HOSTNAME>        : ok=19   changed=4    unreachable=0    failed=1   
```

