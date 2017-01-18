# Building Wallaroo Apps for Bank Machines

## Cluster Start

On your local machine `cd` into the following directory within your `buffy` repo:

```
cd orchestration/arizona
```

Start build machine:
```
make cluster cluster_name=<CLUSTER_NAME> num_followers=<NUMBER_FOLLOWERS> force_instance=r3.4xlarge arizona_node_type=build ansible_system_cpus=0,8
```

SSH onto the build machine:
- the <IP_ADDRESS> is optained after a succesful cluster creation.

```
ssh -i ~/.ssh/ec2/us-east-1.pem ec2-user@<IP_ADDRESS>
```

## Installing `ponyc`

Clone `ponyc` onto the machine:
`
git clone https://github.com/Sendence/ponyc.git
`

cd into `ponyc`:

`cd ponyc`

Checkout to the specific version you want:
`git checkout sendence-15.0.0`

Manual edits to `Makefile`:

Change this line:

`llvm.libs    := $(shell $(LLVM_CONFIG) --libs) -lz -lncurses`

To:

`llvm.libs    := $(shell $(LLVM_CONFIG) --libs) -lz -lncurses -ltinfo`

Change this line:

`  symlink.flags = -srf`
To:

`  symlink.flags = -sf`

### Building `ponyc` for VMs(ivybridge arch)

Test `ponyc`:
```
scl enable devtoolset-4 python27 "LTO_PLUGIN=/opt/rh/devtoolset-4/root/usr/libexec/gcc/x86_64-redhat-linux/5.3.1/liblto_plugin.so make arch=ivybridge prefix=/usr/local  verbose=1 -j`nproc` test"
```

Install `ponyc`:
```
scl enable devtoolset-4 python27 "LTO_PLUGIN=/opt/rh/devtoolset-4/root/usr/libexec/gcc/x86_64-redhat-linux/5.3.1/liblto_plugin.so sudo make arch=ivybridge prefix=/usr/local  verbose=1 install"
```

### Bulding `ponyc` for Physical Machine(nehalem arch)

Test `ponyc`:
```
scl enable devtoolset-4 python27 "LTO_PLUGIN=/opt/rh/devtoolset-4/root/usr/libexec/gcc/x86_64-redhat-linux/5.3.1/liblto_plugin.so make arch=nehalem prefix=/usr/local  verbose=1 -j`nproc` test"
```

Install `ponyc`:
```
scl enable devtoolset-4 python27 "LTO_PLUGIN=/opt/rh/devtoolset-4/root/usr/libexec/gcc/x86_64-redhat-linux/5.3.1/liblto_plugin.so sudo make arch=nehalem prefix=/usr/local  verbose=1 install"
```

## Install `pony-stable`
Clone onto your machine:
`git clone https://github.com/jemc/pony-stable.git`

`cd` into the project:

`
cd pony-stable
`

Make and install:

```
scl enable devtoolset-4 python27 "make"
```
```
scl enable devtoolset-4 python27 "sudo make install"
```

## Building Wallaroo Apps:

Clone `buffy` onto the machine:
`git clone https://github.com/sendence/buffy.git`

cd into the repo:
`cd buffy`

### Building for VM(ivybridge arch)
```
scl enable devtoolset-4 python27 "make build-apps-market-spread PONYCFLAGS='--cpu=ivybridge --link-arch=ivybridge'"
```

### Building for Phsyical Machine(nehalem arch)

```
scl enable devtoolset-4 python27 "make build-apps-market-spread PONYCFLAGS='--cpu=nehalem --link-arch=nehalem'"
```
