"use strict";

const pulumi = require("@pulumi/pulumi");
const azure = require("@pulumi/azure");

let environment = "Development";
let config = new pulumi.Config();

let resourceGroupName = config.require("resourcegroup-name");
let location = config.require("location");
let vmName = config.require("vm-name");
let networkName = config.require("vnet-name");
let nicName = config.require("nic-name");
let ipName = config.require("ip-name");
let projectName = config.require("project-name");
let osImage = config.require("os-image");
let sshPath = config.require("ssh-path");
let sshKeyData = config.require("ssh-key-data");
let vmSku = config.require("vm-sku");
let username = config.require("username");
let password = config.require("password");

let customImageId = config.require("custom-os-image-id");

let osImageArgs = osImage.split(":");
let osImagePublisher = osImageArgs[0];
let osImageOffer = osImageArgs[1];
let osImageSku = osImageArgs[2];
let osImageVersion = "latest";

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
    subnets: [{
        name: "default",
        addressPrefix: "10.0.1.0/24",
    }],
    tags: {
    	environment: environment,
    	project: projectName
    }
});

let publicIP = new azure.network.PublicIp(ipName, {
	name: ipName,
    resourceGroupName: resourceGroup.name,
    allocationMethod: "Dynamic",
    tags: {
    	environment: environment,
    	project: projectName
    }
});

let networkInterface = new azure.network.NetworkInterface(nicName, {
	name: nicName,
    resourceGroupName: resourceGroup.name,
    enableAcceleratedNetworking: true,
    ipConfigurations: [{
        name: `${nicName}-ipcfg`,
        subnetId: network.subnets[0].id,
        privateIpAddressAllocation: "Dynamic",
        publicIpAddressId: publicIP.id,
    }],
    tags: {
    	environment: environment,
    	project: projectName
    }
});

var storageImageReference;

if (customImageId !== '') {
	storageImageReference = {
		id: customImageId
	}
} else {
	storageImageReference = {
        publisher: osImagePublisher,
        offer: osImageOffer,
        sku: osImageSku,
        version: osImageVersion,
    }
}

var vm;

if (customImageId !== '') {
	vm = new azure.compute.VirtualMachine(vmName, {
		name: vmName,
	    resourceGroupName: resourceGroup.name,
	    networkInterfaceIds: [networkInterface.id],
	    vmSize: vmSku,
	    deleteDataDisksOnTermination: true,
	    deleteOsDiskOnTermination: true,
	    osProfileLinuxConfig: {
	        disablePasswordAuthentication: true,
	        sshKeys: [{
	        	path: sshPath,
	        	keyData: sshKeyData,
	        }],
	    },
	    storageOsDisk: {
	        createOption: "FromImage",
	        name: `${vmName}-osdisk`,
	    },
	    storageImageReference: {
	        id: customImageId,
	    },
	    tags: {
	    	environment: environment,
	    	project: projectName
	    }
	});
} else {
	vm = new azure.compute.VirtualMachine(vmName, {
		name: vmName,
	    resourceGroupName: resourceGroup.name,
	    networkInterfaceIds: [networkInterface.id],
	    vmSize: vmSku,
	    deleteDataDisksOnTermination: true,
	    deleteOsDiskOnTermination: true,
	    osProfile: {
	        computerName: "hostname",
	        adminUsername: username,
	        adminPassword: password,
	    },
	    osProfileLinuxConfig: {
	        disablePasswordAuthentication: true,
	        sshKeys: [{
	        	path: sshPath,
	        	keyData: sshKeyData,
	        }],
	    },
	    storageOsDisk: {
	        createOption: "FromImage",
	        name: `${vmName}-osdisk`,
	    },
	    storageImageReference: {
	        publisher: osImagePublisher,
	        offer: osImageOffer,
	        sku: osImageSku,
	        version: osImageVersion,
	    },
	    tags: {
	    	environment: environment,
	    	project: projectName
	    }
	});
}

// The public IP address is not allocated until the VM is running, so we wait
// for that resource to create, and then lookup the IP address again to report
// its public IP.
exports.publicIP = pulumi.all({ id: vm.id, name: publicIP.name, resourceGroupName: publicIP.resourceGroupName }).apply(ip =>
    azure.network.getPublicIP({
        name: ip.name,
        resourceGroupName: ip.resourceGroupName,
    }, { async: true }).then(ip => ip.ipAddress)
);

