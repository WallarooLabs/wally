#!/bin/sh
#set -x
vmss_name=$1
num_leaders=$2
num_followers=$3
total=$((num_leaders + num_followers))

leader_instance_ips=$(gcloud compute instances list --filter="name~'$instance_group_manager_name'" --format json \
	| jq ".[0:$num_leaders] | .[].networkInterfaces[0].accessConfigs[0].natIP")

follower_instance_ips=$(gcloud compute instances list --filter="name~'$instance_group_manager_name'" --format json \
	| jq ".[$num_leaders:$total] | .[].networkInterfaces[0].accessConfigs[0].natIP")

echo "[wallaroo-leaders]"
for ipAddress in $leader_instance_ips; do
	echo "$ipAddress"
done

echo "[wallaroo-followers]"
for ipAddress in $follower_instance_ips; do
	echo "$ipAddress"
done
