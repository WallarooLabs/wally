"use strict";

const pulumi = require("@pulumi/pulumi");
const azure = require("@pulumi/azure");

let environment = "Development";
let config = new pulumi.Config();

let resourceGroupName = config.require("resourcegroup-name");
let location = config.require("location");
let networkName = config.require("vnet-name");
let subnetName = config.require("subnet-name");
let nsgName = config.require("nsg-name");
let projectName = config.require("project-name");

let resourceGroup = new azure.core.ResourceGroup(resourceGroupName, {
    name: resourceGroupName,
    location: location,
    tags: {
        environment: environment,
        project: projectName
    }
});

let network = new azure.network.VirtualNetwork(networkName, {
    name: networkName,
    resourceGroupName: resourceGroup.name,
    addressSpaces: ["10.0.0.0/16"],
    // Workaround two issues:
    // (1) The Azure API recently regressed and now fails when no subnets are defined at Network creation time.
    // (2) The Azure Terraform provider does not return the ID of the created subnets - so this cannot actually be used.
    subnets: [{
        name: "default",
        addressPrefix: "10.0.1.0/24",
    }],
    tags: {
        environment: environment,
        project: projectName
    }
});

let networkSecurityGroup = new azure.network.NetworkSecurityGroup(nsgName, {
    location: resourceGroup.location,
    name: nsgName,
    resourceGroupName: resourceGroup.name,
    securityRules: [{
        access: "Allow",
        destinationAddressPrefix: "*",
        destinationPortRange: "22",
        direction: "Inbound",
        name: "AllowSSH",
        priority: 100,
        protocol: "Tcp",
        sourceAddressPrefix: "*",
        sourcePortRange: "*",
    },
    {
        access: "Allow",
        destinationAddressPrefix: "*",
        destinationPortRange: "*",
        direction: "Inbound",
        name: "AllowInboundInternetAccess",
        priority: 200,
        protocol: "*",
        sourceAddressPrefix: "*",
        sourcePortRange: "*",
    },
    {
        access: "Allow",
        destinationAddressPrefix: "*",
        destinationPortRange: "*",
        direction: "Outbound",
        name: "AllowOutboundInternetAccess",
        priority: 300,
        protocol: "*",
        sourceAddressPrefix: "*",
        sourcePortRange: "*",
    }],
    tags: {
        environment: environment,
        project: projectName
    }
});

let subnet = new azure.network.Subnet(subnetName, {
    name: subnetName,
    resourceGroupName: resourceGroup.name,
    virtualNetworkName: network.name,
    addressPrefix: "10.0.2.0/24",
    tags: {
        environment: environment,
        project: projectName
    }
});

let subnetNetworkSecurityGroupAssociation = new azure.network.SubnetNetworkSecurityGroupAssociation(subnetName + "_nsg-assn", {
    networkSecurityGroupId: networkSecurityGroup.id,
    subnetId: subnet.id,
    tags: {
        environment: environment,
        project: projectName
    }
});

exports.resourceGroupName = resourceGroup.name;
exports.subnetName = subnet.name;
exports.vnetName = network.name;

