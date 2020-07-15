#!/bin/sh
#set -x
vmss_name=$1
resource_group_name=$2

leader_instance_ip=$(az vm list-ip-addresses -n $vmss_name -g $resource_group_name \
	| jq ". | .[].virtualMachine.network.publicIpAddresses | .[0].ipAddress")

echo "[wallaroo-leader-1]"
echo "$leader_instance_ip"

echo "[wallaroo-leaders]"
echo "$leader_instance_ip"
