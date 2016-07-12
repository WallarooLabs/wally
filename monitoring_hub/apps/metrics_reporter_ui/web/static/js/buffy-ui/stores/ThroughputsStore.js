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
		let state = Map().set("source-sink", Map())
					 .set("ingress-egress", Map())
					 .set("step", Map())
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
			.sort(Comparators.propFor("time"))
			.filter(d => {
				return now - d.get("time") < minutes(15)
			});
		return state.setIn([category, metricsKey], updatedThroughputsList);
	}
	filterInitialTotalThroughputsData(state, category, metricsKey, throughputs) {
		const now = toSeconds(Date.now());
		let sortedTotalThroughputsList = fromJS(throughputs.data).sort(Comparators.propFor("time"))
			.filter(d => {
				return now - d.get("time") < minutes(15)
			});
			return state.setIn([category, metricsKey], sortedTotalThroughputsList);
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_TOTAL_THROUGHPUT.actionType:
				category = "step";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_SOURCE_SINK_TOTAL_THROUGHPUT.actionType:
				category = "source-sink";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_INGRESS_EGRESS_TOTAL_THROUGHPUT.actionType:
				category = "ingress-egress";
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_STEP_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "step";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_SOURCE_SINK_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "source-sink";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_INGRESS_EGRESS_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "ingress-egress";
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, category, metricsKey, action["initial-total-throughputs"]);
			default:
				return state;
		}
	}
}

const throughputsStore = new ThroughputsStore(Dispatcher);
export default throughputsStore;