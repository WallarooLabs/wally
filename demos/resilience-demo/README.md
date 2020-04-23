
# How to use these scripts

This README was written in a time where I had too little time to figure out how to use Ansible or perhaps Docker Compose to manage a cluster of machines.  The demo's audience was Wallaroo Labs internal people only, and focused on presenting to Sean & Vid.  The demo's outline was rigid enough that making dedicated scripts to perform each demo step made sense.

A lot has changed in the last 2 years.  But I'm still not enough of an Ansible wizard to be able to quickly adapt this demo's scripting to Ansible.  So, the shell scripting remains.

## Prerequisites that these scripts won't/can't do for you

### Prerequisite: set up 4 separate Linux machines/VMs

1. We assume Ubuntu Xenial 64-bit machines have been set up to the
   point that they can boot, have at least one (and perhaps two)
   unique IP addresses, and can run `apt-get` to install software
   packages.

   I have been testing these scripts using AWS EC2 instances of type
   t3.medium + AMI: Ubuntu Server 16.04 LTS (HVM), SSD Volume Type,
   ami-04169656fea786776 in the us-east-1 region / ami-0552e3455b9bc8d50 in the us-east-2 region.

2. All 4 machines/VM/instances ought to have the same capacity.  You
   can get away with provisioning more memory for what the scripts
   call `$SERVER1`.  That machine should have 4GB of RAM.  The other
   machines can probably work with 1GB RAM but really ought to have
   4GB RAM also.

### Prerequisite: OR ELSE: use 1 machine + 127.0.0.1

Technically, it is possible to run these demos on a single machine, using the loopback interface / 127.0.0.1/8 network.  Let's check that each worker is assigned unique TCP ports, etc. ... LEFT OFF HERE.

NOTE: I've tested this using 1 fresh Ubuntu Xenial VM.  I have not tested it on macOS.  Most of these scripts probably run fine on macOS, but the `00*` and `10*` scripts are very Linux-centric, sorry.

### Prerequisite: edit the COMMON.sh script

The [`COMMON.sh`](./COMMON.sh) script in this directory needs to be
edited to reflect the IP addresses of the 4 machines/VMs that will
execute the demos.

Please see the comments embedded in the [`COMMON.sh`](./COMMON.sh)
script for greater detail.

Perform these steps:

1. Copy `COMMON-4machine.sh` to `COMMON.sh`.
   * If using the 1 machine + localhost variation, instead, copy `COMMON-localhost` to `COMMON.sh`.
2. Edit the `SERVER*EXT` and `SERVER?` IP addresses to reflect the external and internal IP addresses of your EC2 instances (or your localhost addresses).

### Prerequisites: SSH access

We assume that the SSH (remote secure shell) service is available
to all 4 machines/VMs without password prompts.  We strongly
recommend configuring & using SSH's `$HOME/.ssh/authorized_keys`
mechanism.

All scripts assume that the demo initiator machine is *NOT* one of the
target machines/VMs.  Therefore, all target machines/VMs must allow
SSH session from the demo initiator machine.

In some scripts, SSH is used to run commands (such as `rsync`)
between machines/VMs, e.g., an SSH session initiated by `$SERVER1`
to `$SERVER2`.  All target machines must be permitted to initiate SSH
sessions to all other target machines.

### Prerequisite: network firewall stuff

1. We assume that the machine running these scripts may not be one of
   the four target machines/VMs used to execute the demos. For
   example, let's assume that you run these demo scripts on your
   laptop in your home office network.

   If you have a network firewall anywhere between your laptop and the
   target machines/VMs must not block any traffic to or from the
   target machines/VMs.

2. If you have a firewall that affects the target machines/VMs, then
   all traffic between all target machines must be permitted.

3. The scripts are written with the assumption that the target
   machines/VMs have a private internet LAN network.  If this is not a
   valid assumption, then set the following values in the `COMMON.sh`
   script.

    $SERVER1=$SERVER1_EXT
    $SERVER2=$SERVER2_EXT
    $SERVER3=$SERVER3_EXT
    $SERVER4=$SERVER4_EXT

### Prerequisite: Set up the runtime environment on all target machines/VMs

If working with newly-created VMs, or if localhost needs to have the Pony compiler + dependencies installed (we will use `wallaroo-up`), then ... on your laptop, run the following:

    ./00-setup-dev-env.sh

Next, run the following to clone the Wallaroo repo, checkout out the test branch, and compile Wallaroo + dependent utilities.  If your Wallaroo source is already at `$HOME/wallaroo` on the `$SERVER1` machine, note that this script will switch branches: it will checkout the `$REPO_BRANCH` branch/tag.

    ./10-setup-slf-repo.sh

## Demo scripts and chain-them-together examples

### Demo: a worker restart does not violate message ordering invariants

    ./VERIFY.2worker.simple-restart.sh

### Demo: a worker migration in a 2-worker cluster does not violate message ordering invariants

    ./VERIFY.2worker.sh

### Demo: a worker migration in a 3-worker cluster does not violate message ordering invariants

    ./VERIFY.3worker.sh

### Demo: stop all VERIFY* script processes

    env WALLAROO_BIN=./testing/correctness/apps/multi_partition_detector/multi_partition_detector ./99-stop-everything.sh

### Demo: Start market-spread on a 2-worker cluster

    ./20-start-2worker-cluster.sh

The Wallaroo metrics UI agent will be available at `http://$SERVER1:4000`

### Demo: Start market-spread on a 3-worker cluster

    ./21-start-3worker-cluster.sh

The Wallaroo metrics UI agent will be available at `http://$SERVER1:4000`

### Demo: Start a pair of Orders + NBBO data stream senders

    ./30-start-sender.sh

### Demo: Crash a worker, then migrate the worker's state to a new machine then restart

Start a 3 worker cluster, then crash the `worker2` Wallaroo process on
`$SERVER2` and then move `worker2`'s state over to `$SERVER4` then
restart `worker2` on `$SERVER4`.

    ./21-start-3worker-cluster.sh && \
        ./30-start-sender.sh && sleep 5 && \
        ./40-kill-worker.sh 2 2 && \
        ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4

### Demo: move worker2 from $SERVER2 -> $SERVER4 then restart worker2 several times

    ./20-start-2worker-cluster.sh && \
        ./30-start-sender.sh && sleep 5 && \
        ./40-kill-worker.sh 2 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4
    for i in `seq 1 5`; do \
        sleep 5 ; \
        ./40-kill-worker.sh 2 4 && sleep 1 && ./60-restart-worker.sh 2 4; \
    done

### Demo: 2-worker cluster: move worker2 from $SERVER2 -> $SERVER4 -> $SERVER2 -> $SERVER3

    ./20-start-2worker-cluster.sh && \
        ./30-start-sender.sh && sleep 5 && \
        ./40-kill-worker.sh 2 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4 && sleep 5 && \
        ./40-kill-worker.sh 2 4 && ./50-copy-worker-resilience.sh 2 4 2 && \
        ./60-restart-worker.sh 2 2 && sleep 5 && \
        ./40-kill-worker.sh 2 2 && ./50-copy-worker-resilience.sh 2 2 3 && \
        ./60-restart-worker.sh 2 3

### Demo: 3-worker cluster: move worker2 from $SERVER2 -> $SERVER4 -> $SERVER2 -> $SERVER4

    ./21-start-3worker-cluster.sh && \
        ./30-start-sender.sh && sleep 5 && \
        ./40-kill-worker.sh 2 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4 && sleep 5 && \
        ./40-kill-worker.sh 2 4 && ./50-copy-worker-resilience.sh 2 4 2 && \
        ./60-restart-worker.sh 2 2 && sleep 5 && \
        ./40-kill-worker.sh 2 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4
