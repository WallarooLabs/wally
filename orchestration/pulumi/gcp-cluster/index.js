"use strict";
const pulumi = require("@pulumi/pulumi");
const gcp = require("@pulumi/gcp");

let environment = "development";
let config = new pulumi.Config();

let location = config.require("location");
let zone = config.require("zone");
let sourceImage = config.require("source-image");
let instanceTemplateName = config.require("instance-template-name");
let machineType = config.require("machine-type");
let instanceGroupManagerName = config.require("instance-group-manager-name");
let targetSize = config.require("target-size");
let networkURI = config.require("network-uri");
let subnetworkURI = config.require("subnetwork-uri");
let project = config.require("project");
let projectName = config.require("project-name");


const instanceTemplate = new gcp.compute.InstanceTemplate(instanceTemplateName, {
    // namePrefix: "",
    canIpForward: false,
    disks: [{
    	autoDelete: true,
    	boot: true,
        sourceImage: sourceImage
    }],
    region: location,
    labels: {
        environment: environment,
    },
    machineType: machineType,
    metadata: {
        project: projectName,
    },
    networkInterfaces: [{
        network: networkURI,
        subnetwork: subnetworkURI,
        accessConfigs: [{networkTier: "PREMIUM"}]
    }],
    scheduling: {
        automaticRestart: true
    },
    project: project
});

const instanceGroupManager = new gcp.compute.InstanceGroupManager(instanceGroupManagerName, {
    baseInstanceName:  instanceGroupManagerName + "-base",
    instanceTemplate: instanceTemplate.selfLink,
    targetSize: targetSize,
    project: project,
    zone: zone,
    versions: [{
    	instanceTemplate: instanceTemplate.selfLink,
    	name: "wallaroo-dev"
    }]
});
