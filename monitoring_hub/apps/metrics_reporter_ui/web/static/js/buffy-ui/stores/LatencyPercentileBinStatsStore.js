import {ReduceStore} from "flux/utils"
import Actions from "../actions/Actions"
import Dispatcher from "../../dispatcher/Dispatcher"
import { fromJS, List, Map } from "immutable"


const emptyLatencyPercentileBinStats = Map()
	.set("50.0", 0)
	.set("95.0", 0)
	.set("99.0", 0)
	.set("99.9", 0)
	.set("99.99", 0);

class LatencyPercentileBinStatsStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map()
			.set("start-to-end", Map())
			.set("node-ingress-egress", Map())
			.set("computation", Map())
			.set("pipeline", Map())
			.set("start-to-end-by-worker", Map())
			.set("node-ingress-egress-by-pipeline", Map())
			.set("computation-by-worker", Map())
		return state;
	}
	getLatencyPercentileBinStats(appName, category, metricsKey) {
		if (this.getState().hasIn([appName, category, metricsKey])) {
			return this.getState().getIn([appName, category, metricsKey]);
		} else {
			return emptyLatencyPercentileBinStats;
		}
	}
	storeLatencyPercentileBinStats(appName, category, metricsKey, latencyPercentileBinStats, state) {
		return state.setIn([appName, category, metricsKey], fromJS(latencyPercentileBinStats["latency_stats"]));
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		let appName;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "computation";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "node-ingress-egress";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "start-to-end";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_STEP_BY_WORKER_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "computation-by-worker";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "node-ingress-egress-by-pipeline";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "start-to-end-by-worker";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_PIPELINE_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "pipeline";
				appName = action["latency-percentile-bin-stats"].app_name;
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(appName, category, metricsKey, action["latency-percentile-bin-stats"], state);
			default:
				return state;
		}
	}
}

const latencyPercentileBinStatsStore = new LatencyPercentileBinStatsStore(Dispatcher);
export default latencyPercentileBinStatsStore;
