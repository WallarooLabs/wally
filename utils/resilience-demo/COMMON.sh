# Common variables for controlling the other scripts in this directory.
# I have been testing these scripts using AWS EC2 instances of type
# t3.medium + AMI: Ubuntu Server 16.04 LTS (HVM), SSD Volume Type,
# ami-04169656fea786776 in the us-east-1 region.

# Assumptions:
#
# 1. The machine that runs these scripts need not be a cluster member
#    machine, e.g., run on your Wallaroo Labs laptop/desktop from home.
#
# 2. All machines must permit SSH access via both their external *and*
#    internal IP addresses.
#    a). SSH from your laptop to each cluster member.
#    b). SSH used by rsync from one cluster member directly to another
#        via internal network addresses.
#
# 3. Each machine is running Ubuntu Linux or something similar,
#    supported by Wallaroo Up.
#
# 4. For on/off variables defined here, valid values are only "y" and "n".

# External IP addresses for each of the 4 machines in this cluster.
# Must be routable by the machine that executes these scripts.
SERVER1_EXT=54.210.136.72
SERVER2_EXT=18.206.124.212
SERVER3_EXT=54.235.60.156
SERVER4_EXT=54.210.170.173

# Internal IP addresses for each cluster member.  If there is no internal
# network interface, then define as SERVER1=$SERVER1_EXT, etc.
# The internal IP addresses are useful in environments like AWS EC2.
SERVER1=10.0.121.64
SERVER2=10.0.121.107
SERVER3=10.0.110.166
SERVER4=10.0.103.78

# SSH login user for all machines
USER=ubuntu

# URL for the Wallaroo source repo
# The scripts will only clone this repo once and will not fail/interrupt
# the scripts if the repo already exists.  It's up to the user to manage
# the repo with Git "fetch" & "pull" commands as appropriate, if you're
# doing active code development or debugging.
REPO_URL=https://github.com/slfritchie/wallaroo.git

# Source branch name to test with
####REPO_BRANCH=slf-file-io-journal6
#REPO_BRANCH=s-res-test-f+slf-worker-migration+issue-2370
#REPO_BRANCH=res-merge-1
#REPO_BRANCH=res-merge-1+dos
#REPO_BRANCH=resilience-project+dos
#REPO_BRANCH=resilience-project+dos2
#REPO_BRANCH=static-key-graph+dos3
#REPO_BRANCH=resilience-project+dos4
#REPO_BRANCH=resilience-project+dos5
#REPO_BRANCH=static-key-graph+dos5b
REPO_BRANCH=resilience-project+dos6

# If the environment variable WALLAROO_BIN is set, then use it
# for the path to our Wallaroo executable.
if [ -z "$WALLAROO_BIN" ]; then
    WALLAROO_BIN=./testing/performance/apps/market-spread/market-spread
fi
WALLAROO_NAME=`basename $WALLAROO_BIN`

# TCP source sender control knobs, y/n = on/off
# Override via environment: SEND_INITIAL_NBBO=y
SEND_NBBO=y
SEND_ORDERS=y

# TCP port numbers for NBBO & orders sources
NBBO_PORT=7001
ORDERS_PORT=7000

# DOS server-related flags: if USE_DOS_SERVER=n then following two
# variables will be ignored.
USE_DOS_SERVER=y
DOS_SERVER_EXT=$SERVER1_EXT
DOS_SERVER=$SERVER1

# Choice for data copy step from former/dead worker -> new worker:
# if "n", then rsync all /tmp/market-spread-worker2* files;
# if "y", then only rsync the /tmp/market-spread-worker2*.journal files
#         and then restore all recovery files via journal-dump.py.
RESTORE_VIA_JOURNAL_DUMP=y
