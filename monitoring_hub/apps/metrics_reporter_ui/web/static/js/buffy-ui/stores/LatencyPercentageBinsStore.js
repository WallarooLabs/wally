import {ReduceStore} from "flux/utils";
import Actions from "../actions/Actions";
import Dispatcher from "../../dispatcher/Dispatcher";
import {fromJS, List, Map} from "immutable";

const emptyLatencyPercentageBins = Map();

class LatencyPercentageBinsStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map().set("source-sink", Map())
						 .set("step", Map())
						 .set("ingress-egress", Map());
		return state;
	}
	getLatencyPercentageBins(category, metricsKey) {
		if (this.getState().hasIn([category, metricsKey])) {
			return this.getState().getIn([category, metricsKey]);
		} else {
			return emptyLatencyPercentageBins;
		}
	}
	updateLatencyPercentaneBins(state, category, metricsKey, newLatencyPercentageBinsData) {
		const latencyPercentageBins = fromJS(newLatencyPercentageBinsData["latency_bins"]);
		return this.getState().setIn([category, metricsKey], latencyPercentageBins);
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_LATENCY_PERCENTAGE_BINS.actionType:
				category = "step";
				metricsKey = action["latency-percentage-bins"].pipeline_key;
				return this.updateLatencyPercentaneBins(state, category, metricsKey, action["latency-percentage-bins"]);
			case Actions.RECEIVE_INGRESS_EGRESS_LATENCY_PERCENTAGE_BINS.actionType:
				category = "ingress-egress";
				metricsKey = action["latency-percentage-bins"].pipeline_key;
				return this.updateLatencyPercentaneBins(state, category, metricsKey, action["latency-percentage-bins"]);
			case Actions.RECEIVE_SOURCE_SINK_LATENCY_PERCENTAGE_BINS.actionType:
				category = "source-sink";
				metricsKey = action["latency-percentage-bins"].pipeline_key;
				return this.updateLatencyPercentaneBins(state, category, metricsKey, action["latency-percentage-bins"]);
			default:
				return state;
		}
	}
}

const latencyPercentageBinsStore = new LatencyPercentageBinsStore(Dispatcher);
export default latencyPercentageBinsStore;