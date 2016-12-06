import {ReduceStore} from "flux/utils";
import Actions from "../actions/Actions";
import Comparators from "../../util/Comparators";
import Dispatcher from "../../dispatcher/Dispatcher";
import { fromJS, List, Map } from "immutable";
import {minutes, toSeconds} from "../../util/Duration";

const emptyThroughputs = List();

class ThroughputsStore extends ReduceStore {
	constructor(dispatcher) {
		super(dispatcher);
	}
	getInitialState() {
		let state = Map().set("start-to-end", Map())
					 .set("node-ingress-egress", Map())
					 .set("computation", Map())
		return state;
	}
	getThroughputs(category, metricsKey) {
		if (this.getState().hasIn([category, metricsKey])) {
			return this.getState().getIn([category, metricsKey]);
		} else {
			return emptyThroughputs;
		}
	}
	filterTotalThroughputData(state, category, metricsKey, nextTotalThroughputData) {
		const now = toSeconds(Date.now());
		let throughputsList;
		if (state.hasIn([category, metricsKey])) {
			throughputsList = state.getIn([category, metricsKey]);
		} else {
			throughputsList = List();
		}
		const updatedThroughputsList = throughputsList.push(fromJS(nextTotalThroughputData))
			.filter(d => {
				return now - d.get("time") < minutes(5)
			});
		return state.setIn([category, metricsKey], updatedThroughputsList);
	}
	filterInitialTotalThroughputsData(state, category, metricsKey, throughputs) {
		const now = toSeconds(Date.now());
		let sortedTotalThroughputsList = fromJS(throughputs.data)
			.filter(d => {
				return now - d.get("time") < minutes(5)
			});
			return state.setIn([category, metricsKey], sortedTotalThroughputsList);
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_TOTAL_THROUGHPUT.actionType:
				category = "computation";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_SOURCE_SINK_TOTAL_THROUGHPUT.actionType:
				category = "start-to-end";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_INGRESS_EGRESS_TOTAL_THROUGHPUT.actionType:
				category = "node-ingress-egress";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_STEP_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "computation";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_SOURCE_SINK_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "start-to-end";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_INGRESS_EGRESS_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "node-ingress-egress";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			default:
				return state;
		}
	}
}

const throughputsStore = new ThroughputsStore(Dispatcher);
export default throughputsStore;
