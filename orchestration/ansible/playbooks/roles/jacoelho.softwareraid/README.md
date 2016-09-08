# ansible.softwareraid
`softwareraid` is an [ansible](http://www.ansible.com) role which: 
 * installs mdadm
 * configures raid devices
 * optionally mount the raid devices 


## Variables
```yaml
software_raid_alerts_email: "email@example.com"
software_raid_create_kwargs: "--run" # force the creation if there are any prompts
software_raid_devices:
- device: /dev/md0
  level: 0
  components:
    - /dev/sdb
    - /dev/sdc
  filesystem_type: "ext4"
  mount_point: "/mnt/volume"
  mount_options: "noatime,noexec,nodiratime"
  dump: 0
  passno: 0
- device: /dev/md1
  level: 1
  components:
    - /dev/sdd
    - /dev/sde
```

## Testing

Test against vagrant. Add a yml file and environment variable in the 
make file to tell the Vagrantfile what yml config to run.

```
make test
```
