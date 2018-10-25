# Releasing the publicly-accessible Wallaroo Amazon Machine Images (AMIs)

This document is aimed at members of the Wallaroo team who might be releasing
AMIs for a release candidate or release branch.

To learn more about our release process, see [RELEASE.md](RELEASE.md).

## Prerequisites for releasing the AMIs

The AMI building and publishing process is conducted inside a Vagrant
machine. You'll therefore need:

* Vagrant installed
* A provisioned Wallaroo Release Vagrant box, as described in
  [PROVISION_VAGRANT.md](PROVISION_VAGRANT.md).
* [Valid AWS credentials][aws_creds] in `~/.aws`

## Releasing the AMIs

### Start up Vagrant box

```bash
cd .release
DOCKER_USERNAME=<YOUR_USERNAME> \
DOCKER_PASSWORD=<YOUR_BINTRAY_DOCKER_API_ACCESS_KEY> \
DOCKER_SERVER=wallaroo-labs-docker-wallaroolabs.bintray.io vagrant up
```

Also: please be aware that your local directory `~/.aws` is mounted inside the
Vagrant box under `/home/vagrant/.aws`.


### SSH into Wallaroo Vagrant box

From within the `.release` directory run:

```bash
vagrant ssh
```

This will `ssh` you into the running Wallaroo box.

### Build and publish AMI of your selected Wallaroo version

```bash
./.release/ami-release.sh <BRANCH> <TARGET_AMI_VERSION>
```

This will do the following:

1. Check out Wallaroo at `<BRANCH>`
2. Clean up and then build: `machida`,`cluster_shutdown`,
  `data_receiver`, and `sender`.
3. Launch an EC2 instance of Ubuntu 16.04 and install the
   minimum necessary set of packages to run Wallaroo apps
4. Copy the precompiled binaries from above onto the EC2 instance
5. Take a snapshot of the instance and save it as a public AMI,
   named `Wallaroo <TARGET_AMI_VERSION>`

When the process finishes successfully, the last lines of its output will resemble:

```
Build 'amazon-ebs' finished.

==> Builds finished. The artifacts of successful builds are:
--> amazon-ebs: AMIs were created:

<LIST OF AMIS HERE>

us-west-2: ami-abcdef012
```

### Check that the most recent AMI is available as a Community AMI

* Go to [The EC2 launch wizard][ec2_launch_wizard]
* Click **Community AMIs** (in the sidebar)
* Type `wallaroo` in the Search bar
* Check that the `WALLAROO_VERSION` you intended to build is available.

### Stop the Wallaroo Vagrant Box

After all AMIs have been created successfully, run the following to stop the Vagrant virtual machine:

```bash
vagrant halt
```

## Making modifications to the AMI build process

The build process comprises the following files:

* [`ami-release.sh`](../../.release/ami-release.sh): This script is launched on
  the Vagrant box. It orchestrates the entire build process.
* [`template.json`](../../.release/ami/template.json): The [Packer template][packer_template] for the AMI
* [`ami/initial_system_setup.sh`](../../.release/ami/initial_system_setup.sh):
  This script is run on the EC2 instance. It is responsible for installing the
  runtime dependencies for `machida`, and setting up an `/etc/rc.local` script to run
  on system startup.
* [`regions`](../../.release/ami/regions): A text file listing the AWS regions
  where the public AMI will be available.


[aws_creds]: https://developer.amazon.com/docs/smapi/set-up-credentials-for-an-amazon-web-services-account.html
[ec2_launch_wizard]: https://console.aws.amazon.com/ec2/v2/home?region=us-east-1#LaunchInstanceWizard
[packer_template]: https://www.packer.io/docs/templates/index.html
