import {ReduceStore} from "flux/utils"
import Actions from "../actions/Actions"
import Dispatcher from "../../dispatcher/Dispatcher"
import { fromJS, List, Map } from "immutable"
import {minutes, toSeconds} from "../../util/Duration"

const emptyThroughputStats = Map()
	.set("min", 0)
	.set("med", 0)
	.set("max", 0);

class ThroughputStatsStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map()
			.set("start-to-end", Map())
			.set("node-ingress-egress", Map())
			.set("computation", Map())
			.set("pipeline", Map())
			.set("pipeline-ingestion", Map())
			.set("start-to-end-by-worker", Map())
			.set("computation-by-worker", Map())
			.set("node-ingress-egress-by-pipeline", Map())
		return state;
	}
	getThroughputStats(category, metricsKey) {
		// console.log("Category: " + category + " MetricsKey: " + metricsKey);
		// console.log("Throughput Stats: " + this.getState());
		if (this.getState().hasIn([category, metricsKey])) {
			return this.getState().getIn([category, metricsKey]);
		} else {
			return emptyThroughputStats;
		}
	}
	storeThroughputStats(category, metricsKey, throughputStats, state) {
		return state.setIn([category, metricsKey], fromJS(throughputStats["throughput_stats"]));
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_THROUGHPUT_STATS.actionType:
				category = "computation";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_STEP_BY_WORKER_THROUGHPUT_STATS.actionType:
				category = "computation-by-worker";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_THROUGHPUT_STATS.actionType:
				category = "node-ingress-egress";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_THROUGHPUT_STATS.actionType:
				category = "node-ingress-egress-by-pipeline";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_THROUGHPUT_STATS.actionType:
				category = "start-to-end";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_THROUGHPUT_STATS.actionType:
				category = "start-to-end-by-worker";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_PIPELINE_THROUGHPUT_STATS.actionType:
				category = "pipeline";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_PIPELINE_INGESTION_THROUGHPUT_STATS.actionType:
				category = "pipeline-ingestion";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			default:
				return state;
		}
	}
}

const throughputStatsStore = new ThroughputStatsStore(Dispatcher);
export default throughputStatsStore;
