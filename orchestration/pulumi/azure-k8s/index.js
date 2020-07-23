"use strict";


const azure = require("@pulumi/azure");
const azuread = require("@pulumi/azuread");
const k8s = require("@pulumi/kubernetes");
const pulumi = require("@pulumi/pulumi");
const random = require("@pulumi/random");


let environment = "Development";
let config = new pulumi.Config();

let resourceGroupName = config.require("resourcegroup-name");
let location = config.require("location");
let aksClusterName = config.require("aks-cluster-name");
let appName = config.require("app-name");
let spName = config.require("sp-name");
let projectName = config.require("project-name");
let sshKeyData = config.require("ssh-key-data");
let vmSku = config.require("vm-sku");
let nodeCount = config.require("node-count");
let nodePoolName = config.require("node-pool-name");
let networkPolicy = config.require("network-policy").trim();
let kubernetesVersion = config.require("kubernetes-version");
let dnsPrefix = config.require("dns-prefix");
let username = config.require("username");

const password = new random.RandomPassword("password", {
    length: 16,
    overrideSpecial: "/@\" ",
    special: true,
});

// Create the AD service principal for the K8s cluster.
const adApp = new azuread.Application(appName);
const adSp = new azuread.ServicePrincipal(spName, { applicationId: adApp.applicationId });
const adSpPassword = new azuread.ServicePrincipalPassword("aksSpPassword", {
    servicePrincipalId: adSp.id,
    value: password.result,
    endDate: "2099-01-01T00:00:00Z",
});

// create resource group
let resourceGroup = new azure.core.ResourceGroup(resourceGroupName, {
    name: resourceGroupName,
    location: location,
    tags: {
        environment: environment,
        project: projectName
    }
});

// Now allocate an AKS cluster.
const k8sCluster = new azure.containerservice.KubernetesCluster(aksClusterName, {
    name: aksClusterName,
    resourceGroupName: resourceGroup.name,
    location: location,
    agentPoolProfiles: [{
        name: nodePoolName,
        count: nodeCount,
        vmSize: vmSku,
    }],
    dnsPrefix: dnsPrefix,
    linuxProfile: {
        adminUsername: username,
        sshKey: {
	        keyData: sshKeyData,
        },
    },
    networkProfile: {
		networkPlugin: "azure",
		networkPolicy: networkPolicy,
		dnsServiceIp: "10.2.0.10",
		dockerBridgeCidr: "172.17.0.1/16",
		serviceCidr: "10.2.0.0/24"
	},
    servicePrincipal: {
        clientId: adApp.applicationId,
        clientSecret: adSpPassword.value,
    },
    kubernetesVersion: kubernetesVersion,
    // TODO: Determine whether it's beneficial to name this on our
    // own or continue to allow the name to be generated
    // nodeResourceGroup: resourceGroup.name,
    tags: {
        environment: environment,
        project: projectName
    }
});

// Expose a K8s provider instance using our custom cluster instance.
const k8sProvider = new k8s.Provider("aksK8s", {
    kubeconfig: k8sCluster.kubeConfigRaw,
});

exports.k8sProvider = k8sProvider;
exports.k8sCluster = k8sCluster;
exports.aksClusterName = aksClusterName;
