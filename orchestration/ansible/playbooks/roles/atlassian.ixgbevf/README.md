# atlassian.ixgbevf

Installs the Intel ixgbevf driver required for AWS Enhanced Networking (SR-IOV) using DMKS.

## Requirements

Your system needs to support [Dynamic Kernel Module Support ](https://help.ubuntu.com/community/DKMS).

## Role Variables

The ixgbevf role has two variables

      ixgbevf_version: 2.16.4
      ixgbevf_tar_sha1_hash: 110fa89c30b029e946ed73105c471cf03f1767be

Check https://sourceforge.net/projects/e1000/files/ixgbevf%20stable/ for these values and update them accordingly.

## Usage

In this example we configure a newer driver for our r3.x4large hosts in AWS EC2.

    - hosts: r3.4xlarge
      roles:
         - { role: atlassian.ixgbevf, ixgbevf_version: 2.16.4, ixgbevf_tar_sha1_hash: 110fa89c30b029e946ed73105c471cf03f1767be }

If your experiencing issues during builds you can optional store a copy of the ixgbevf source in the *files/* path to prevent a remote download. 

## Known Issues

* No support for RHEL based operating systems yet
* Moving to a EC2 instance type which does not support Enhanced Networking will cause your system to fail
