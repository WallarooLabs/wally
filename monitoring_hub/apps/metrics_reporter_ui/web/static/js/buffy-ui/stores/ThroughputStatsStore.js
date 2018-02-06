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
		let state = Map();
		return state;
	}
	getThroughputStats(appName, category, metricsKey) {
		if (this.getState().hasIn([appName, category, metricsKey])) {
			return this.getState().getIn([appName, category, metricsKey]);
		} else {
			return emptyThroughputStats;
		}
	}
	storeThroughputStats(appName, category, metricsKey, throughputStats, state) {
		return state.setIn([appName, category, metricsKey], fromJS(throughputStats["throughput_stats"]));
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		let appName;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_THROUGHPUT_STATS.actionType:
				category = "computation";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_STEP_BY_WORKER_THROUGHPUT_STATS.actionType:
				category = "computation-by-worker";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_THROUGHPUT_STATS.actionType:
				category = "node-ingress-egress";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_THROUGHPUT_STATS.actionType:
				category = "node-ingress-egress-by-pipeline";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_THROUGHPUT_STATS.actionType:
				category = "start-to-end";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_THROUGHPUT_STATS.actionType:
				category = "start-to-end-by-worker";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_PIPELINE_THROUGHPUT_STATS.actionType:
				category = "pipeline";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_PIPELINE_INGESTION_THROUGHPUT_STATS.actionType:
				category = "pipeline-ingestion";
				appName = action["throughput-stats"].app_name;
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(appName, category, metricsKey, action["throughput-stats"], state);
			default:
				return state;
		}
	}
}

const throughputStatsStore = new ThroughputStatsStore(Dispatcher);
export default throughputStatsStore;
