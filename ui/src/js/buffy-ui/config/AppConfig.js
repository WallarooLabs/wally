export default {
	SYSTEM_KEYS: {
		MARKET_SPREAD_CHECK: {
			name: "Market Spread Check",
			path: "market-spread-check",
			key: "MARKET_SPREAD_CHECK",
			pipelineKeys: {
				NBBO: {
					name: "Market Data NBBO",
					key: "NBBO",
					path: "market-data-nbbo",
					channelKey: "NBBO"
				},
				PRICE_SPREAD: {
					name: "Price Spread Order Check",
					key: "PRICE_SPREAD",
					path: "price-spread",
					channelKey: "PRICE_SPREAD"
				},
				NODE_1: {
					name: "Market Data Node 1",
					key: "NODE_1",
					path: "market-data-node-1",
					channelKey: "NODE_1"
				}
			}
		},
		CLIENT_LIMIT_CHECK: {
			name: "Client Limit Check",
			path: "client-limit-check",
			key: "CLIENT_LIMIT_CHECK",
			pipelineKeys: {
				CLIENT_LIMIT: {
					name: "Client Order Limit Check",
					key: "CLIENT_LIMIT",
					path: "client-limit",
					channelKey: "CLIENT_LIMIT"
				}
			}
		},
		INTERNAL_MONITORING: {
			name: "Internal Monitoring System",
			path: "internal-monitoring-system",
			key: "INTERNAL_MONITORING",
			pipelineKeys: {
				CLIENT_LIMIT_ACTIONABLE: {
					name: "Client Limit Check Actionable",
					key: "CLIENT_LIMIT_ACTIONABLE",
					path: "client-limit-actionable",
					channelKey: "CLIENT_LIMIT_ACTIONABLE"
				},
				PRICE_SPREAD_ACTIONABLE: {
					name: "Price Spread Check Actionable",
					key: "PRICE_SPREAD_ACTIONABLE",
					path: "price-spread-actionable",
					channelKey: "PRICE_SPREAD_ACTIONABLE"
				},
				NBBO_ACTIONABLE: {
					name: "Market Data Actionable",
					key: "NBBO_ACTIONABLE",
					path: "nbbo-actionable",
					channelKey: "NBBO_ACTIONABLE"
				}
			}		
		}
	},
	getChannelKey(systemKey, pipelineKey) {
		return this.SYSTEM_KEYS[systemKey].pipelineKeys[pipelineKey].channelKey;
	},
	getSystemKey(systemKey) {
		return this.SYSTEM_KEYS[systemKey].key;
	},
	getSystemPipelineKeys(systemKey) {
		return this.SYSTEM_KEYS[systemKey].pipelineKeys;
	},
	getPipelineName(systemKey, pipelineKey) {
		return this.SYSTEM_KEYS[systemKey].pipelineKeys[pipelineKey].name;
	},
	getSystemName(systemKey) {
		return this.SYSTEM_KEYS[systemKey].name;
	},
	getPipelinePath(systemKey, pipelineKey) {
		return this.SYSTEM_KEYS[systemKey].pipelineKeys[pipelineKey].path;
	},
	getSystemPath(systemKey) {
		return this.SYSTEM_KEYS[systemKey].path;
	},
	getPipelineKey(systemKey, pipelineKey) {
		return this.SYSTEM_KEYS[systemKey].pipelineKeys[pipelineKey].key;
	}
}