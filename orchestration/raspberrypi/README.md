# Wallaroo Raspberry Pi Orchestration

This module consists of the orchestration for Wallaroo on Raspberry Pis.

## Hypriot on RPi

In order to configure the Hypriot nodes you need to do the following...

### Starting point

NOTE: These instructions and the ansible playbook were tested with 
`Version 0.7.0 Berry (beta)` of the `Hypriot Docker Image for Raspberry Pi` list
from the Hypriot download page (http://blog.hypriot.com/downloads/).
Theoretically other versions should also work if you're feeling adventurous.

#### Using `make`

```
make flash-rpi-node node_hostname=<NODE_NAME>
```

#### Hypriot flash utility

The ansible playbook and the instructions below assume that every node was
flashed using the Hypriot flash utility (https://github.com/hypriot/flash) using
the following command:

```
<PATH_TO_UTILITY>/flash --hostname <HOSTNAME> <PATH_TO_IMAGE>
```

### Hosts file

Create a `hosts` file with the following format identifying all leader/follower
nodes:

```
[wallaroo-leaders]
<LEADER_HOSTNAME>.local
<LEADER_HOSTNAME>.local

[wallaroo-followers]
<FOLLOWER_HOSTNAME>.local
<FOLLOWER_HOSTNAME>.local
<FOLLOWER_HOSTNAME>.local

```

NOTE: Please use the `<HOSTNAME>.local` as mentioned because the ansible
playbook will change the ip address from being dynamically assigned to being
statically assigned including renumbering nodes and it will only successfully be
able to complete installing and configuring ptpd/docker/etc if the dns name is
used.

### Copy ssh key to nodes

Use the following to copy a ssh key to every node for passwordless
authentication:

`ssh-copy-id -i <PATH/TO/PUBLIC/KEY> root@<HOSTNAME>.local`

### Test Ansible connection to nodes

Test your Ansible connection to the nodes by running:

`ansible all -i hosts --ssh-extra-args="-o StrictHostKeyChecking=no -i <PATH/TO/PRIVATE/KEY>" -u root -m ping`

NOTE: `<PATH/TO/PRIVATE/KEY>` must be an absolute path or else ansible doesn't
work properly on OSX.

If you're able to successfully connect and Python is installed already you will
see:

```
<NODE_IP_HOSTNAME> | SUCCESS => {
    "changed": false, 
    "ping": "pong"
}
```

If you're able to successfully connect and Python is not installed already you
will see:

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

Both of these are good/acceptable results because they both confirm that Ansible
is able to successfully use passwordless ssh to authenticate with the nodes.

### Run Ansible playbook to configure nodes

Now that you're successfully able to connect to the nodes, you can run the
Ansible playbook to configure them.

#### Using `make`

```
make configure-rpi private_key=<PATH_TO_PRIVATE_KEY>
```

#### Using ansible directly

`ansible-playbook -i hosts --ssh-extra-args="-o StrictHostKeyChecking=no -i <PATH/TO/PRIVATE/KEY>" -u root playbooks/hypriot.yml`

NOTE: `<PATH/TO/PRIVATE/KEY>` must be an absolute path or else ansible doesn't
work properly on OSX.

#### Output

Assuming no errors you'll see something like the following at the end of the
output:

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

