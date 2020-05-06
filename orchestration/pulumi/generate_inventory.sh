#!/bin/sh
#set -x
vmss_name=$1
resource_group_name=$2
num_leaders=$3
num_followers=$4
total=$((num_leaders + num_followers))

leader_instance_ips=$(az vmss list-instance-public-ips -n $vmss_name -g $resource_group_name \
	| jq ".[0:$num_leaders] | .[].ipAddress")

follower_instance_ips=$(az vmss list-instance-public-ips -n $vmss_name -g $resource_group_name \
	| jq ".[$num_leaders:$total] | .[].ipAddress")

INDEX=1
for ipAddress in $leader_instance_ips; do
	echo "[wallaroo-leader-$INDEX]"
	echo "$ipAddress"
	let INDEX=${INDEX}+1
done

INDEX=1
for ipAddress in $follower_instance_ips; do
	echo "[wallaroo-follower-$INDEX]"
	echo "$ipAddress"
	let INDEX=${INDEX}+1
done


echo "[wallaroo-leaders]"
for ipAddress in $leader_instance_ips; do
	echo "$ipAddress"
done

echo "[wallaroo-followers]"
for ipAddress in $follower_instance_ips; do
	echo "$ipAddress"
done
