
# How to use these scripts

## Prerequisites that these scripts won't/can't do for you

### Prerequisite: set up 4 separate Linux machines/VMs

1. We assume Ubuntu Xenial 64-bit machines have been set up to the
   point that they can boot, have at least one (and perhaps two)
   unique IP addresses, and can run `apt-get` to install software
   packages.

   I have been testing these scripts using AWS EC2 instances of type
   t3.medium + AMI: Ubuntu Server 16.04 LTS (HVM), SSD Volume Type,
   ami-04169656fea786776 in the us-east-1 region.

2. All 4 machines/VM/instances ought to have the same capacity.  You
   can get away with provisioning more memory for what the scripts
   call `$SERVER1`.  That machine should have 4GB of RAM.  The other
   machines can probably work with 1GB RAM but really ought to have
   4GB RAM also.

### Prerequisite: edit the COMMON.sh script

The [`COMMON.sh`](./COMMON.sh) script in this directory needs to be
edited to reflect the IP addresses of the 4 machines/VMs that will
execute the demos.

Please see the comments embedded in the [`COMMON.sh`](./COMMON.sh)
script for greater detail.

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

On your laptop, run the following two commands:

    ./00-setup-dev-env.sh
    ./10-setup-slf-repo.r=on.sh

# Demo: Verify that a worker restart does not disrupt sequence window verification

    ./VERIFY.2worker.simple-restart.sh

# Demo: Verify that a worker migration in a 2-worker cluster does not disrupt sequence window verification

    ./VERIFY.2worker.sh

# Demo: Verify that a worker migration in a 3-worker cluster does not disrupt sequence window verification

    ./VERIFY.3worker.sh

# Demo: Start market-spread on a 2-worker cluster

    ./20-start-2worker-cluster.sh

The Wallaroo metrics UI agent will be available at `http://$SERVER1:4000`

# Demo: Start market-spread on a 2-worker cluster

    ./21-start-3worker-cluster.sh

The Wallaroo metrics UI agent will be available at `http://$SERVER1:4000`

# Demo: Start a pair of Orders + NBBO data stream senders

    ./30-start-sender.sh

# Demo: Crash a worker, then migrate the worker's state to a new machine then restart

We will crash the `worker2` Wallaroo process on `$SERVER2` and then
move `worker2`'s state over to `$SERVER4` then restart `worker2` on
`$SERVER4`.

    ./40-kill-worker.sh 2 && \
        ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4

# Demo: move worker2 from $SERVER2 -> $SERVER4  then restart several times

    ./20-start-2worker-cluster.sh && \
        ./30-start-sender.sh && sleep 3 && \
        ./40-kill-worker.sh 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4
    for i in `seq 1 5`; do \
        sleep 3 ; \
        ./40-kill-worker.sh 4 && sleep 1 && ./60-restart-worker.sh 2 4; \
    done

# Demo: 2-worker cluster: move worker2 from $SERVER2 -> $SERVER4 -> $SERVER2 -> $SERVER3

    ./20-start-2worker-cluster.sh && \
        ./30-start-sender.sh && sleep 3 && \
        ./40-kill-worker.sh 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4 && sleep 3 && \
        ./40-kill-worker.sh 4 && ./50-copy-worker-resilience.sh 2 4 2 && \
        ./60-restart-worker.sh 2 2 && sleep 3 && \
        ./40-kill-worker.sh 2 && ./50-copy-worker-resilience.sh 2 2 3 && \
        ./60-restart-worker.sh 2 3

# Demo: 3-worker cluster: move worker2 from $SERVER2 -> $SERVER4 -> $SERVER2 -> $SERVER4

    ./21-start-3worker-cluster.sh && \
        ./30-start-sender.sh && sleep 3 && \
        ./40-kill-worker.sh 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4 && sleep 3 && \
        ./40-kill-worker.sh 4 && ./50-copy-worker-resilience.sh 2 4 2 && \
        ./60-restart-worker.sh 2 2 && sleep 3 && \
        ./40-kill-worker.sh 2 && ./50-copy-worker-resilience.sh 2 2 4 && \
        ./60-restart-worker.sh 2 4
