import {ReduceStore} from "flux/utils"
import Actions from "../actions/Actions"
import Dispatcher from "../../dispatcher/Dispatcher"
import { fromJS, List, Map } from "immutable"


const emptyLatencyPercentileBinStats = Map()
	.set("50.0", 0)
	.set("75.0", 0)
	.set("90.0", 0)
	.set("99.0", 0)
	.set("99.9", 0);

class LatencyPercentileBinStatsStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map()
			.set("source-sink", Map())
			.set("ingress-egress", Map())
			.set("step", Map())
		return state;
	}
	getLatencyPercentileBinStats(category, metricsKey) {
		if (this.getState().hasIn([category, metricsKey])) {
			return this.getState().getIn([category, metricsKey]);
		} else {
			return emptyLatencyPercentileBinStats;
		}
	}
	storeLatencyPercentileBinStats(category, metricsKey, latencyPercentileBinStats, state) {
		return state.setIn([category, metricsKey], fromJS(latencyPercentileBinStats["latency_stats"]));
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "step";
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "ingress-egress";
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(category, metricsKey, action["latency-percentile-bin-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_LATENCY_PERCENTILE_BIN_STATS.actionType:
				category = "source-sink";
				metricsKey = action["latency-percentile-bin-stats"].pipeline_key;
				return this.storeLatencyPercentileBinStats(category, metricsKey, action["latency-percentile-bin-stats"], state);
			default:
				return state;
		}
	}
}

const latencyPercentileBinStatsStore = new LatencyPercentileBinStatsStore(Dispatcher);
export default latencyPercentileBinStatsStore;