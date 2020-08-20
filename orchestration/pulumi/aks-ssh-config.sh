#! /bin/bash

kube_rg=$(az group list -o json | jq -r  --arg CLUSTERNAME "$1" '.[] | select(.name|test("MC.")) | select(.name|test($CLUSTERNAME)) | .name')

az network public-ip create -g $kube_rg -n kube-ip

nic_name=$(az network nic list -g $kube_rg -o json | jq -r '.[0].name')

az network nic ip-config update -g $kube_rg --nic-name $nic_name --name ipconfig1 --public-ip-address kube-ip

kube_nsg=$(az network nsg list -g $kube_rg -o json | jq -r '.[0].name')

az network nsg rule create -g $kube_rg --nsg-name $kube_nsg -n SshRule --priority 100 --source-address-prefixes Internet --destination-port-ranges 22 --access Allow --protocol Tcp --direction Inbound

pub_ip=$(az network public-ip show -g $kube_rg -n kube-ip -o json | jq -r '.ipAddress')

echo "KUBERNETES NODE PUBLIC IP: $pub_ip"
