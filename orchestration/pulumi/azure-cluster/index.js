"use strict";

const pulumi = require("@pulumi/pulumi");
const azure = require("@pulumi/azure");

let config = new pulumi.Config();

const vmssName = config.require("vmss-name");
const vmssId = config.require("vmss-id");

const vmss = azure.compute.ScaleSet.get(vmssName, vmssId);




