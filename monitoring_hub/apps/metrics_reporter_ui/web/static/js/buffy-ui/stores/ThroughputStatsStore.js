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
			.set("source-sink", Map())
			.set("ingress-egress", Map())
			.set("step", Map())
		return state;
	}
	getThroughputStats(category, metricsKey) {
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
				category = "step";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_INGRESS_EGRESS_THROUGHPUT_STATS.actionType:
				category = "ingress-egress";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			case Actions.RECEIVE_SOURCE_SINK_THROUGHPUT_STATS.actionType:
				category = "source-sink";
				metricsKey = action["throughput-stats"].pipeline_key;
				return this.storeThroughputStats(category, metricsKey, action["throughput-stats"], state);
			default:
				return state;
		}
	}
}

const throughputStatsStore = new ThroughputStatsStore(Dispatcher);
export default throughputStatsStore;