"use strict";
const pulumi = require("@pulumi/pulumi");
const gcp = require("@pulumi/gcp");

let environment = "Development";
let config = new pulumi.Config();

let location = config.require("location");
let networkName = config.require("vnet-name");
let subnetName = config.require("subnet-name");
let firewallName = config.require("firewall-name");
let project = config.require("project");
let projectName = config.require("project-name");

const computeNetwork = new gcp.compute.Network(networkName, {
    autoCreateSubnetworks: false,
    project: project,
    metadata: {
        project: projectName,
    }
});

const computeSubnet = new gcp.compute.Subnetwork(subnetName, {
	ipCidrRange: "10.0.2.0/24",
	network: computeNetwork.selfLink,
	project: project,
	region: location,
    metadata: {
        project: projectName,
    }
})

const computeFirewall = new gcp.compute.Firewall(firewallName, {
    network: computeNetwork.selfLink,
    project: project,
    priority: 1000,
    allows: [{
        protocol: "tcp",
    }],
    metadata: {
        project:projectName,
    }
});

exports.networkURI = computeNetwork.selfLink;
exports.subnetURI = computeSubnet.selfLink;
exports.firewallURI = computeFirewall.selfLink;
