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
		let state = Map()
		return state;
	}
	getThroughputs(appName, category, metricsKey) {
		if (this.getState().hasIn([appName, category, metricsKey])) {
			return this.getState().getIn([appName, category, metricsKey]);
		} else {
			return emptyThroughputs;
		}
	}
	filterTotalThroughputData(state, appName, category, metricsKey, nextTotalThroughputMsg) {
		let sortedThroughputsList = fromJS(nextTotalThroughputMsg.data).sort(
			(a,b) => {
				a.get("time") - b.get("time")
			}
		)
		return state.setIn([appName, category, metricsKey], sortedThroughputsList);
	}
	filterInitialTotalThroughputsData(state, appName, category, metricsKey, nextTotalThroughputMsg) {
		let sortedThroughputsList = fromJS(nextTotalThroughputMsg.data).sort(
			(a,b) => {
				a.get("time") - b.get("time")
			}
		)
		return state.setIn([appName, category, metricsKey], sortedThroughputsList);
	}
	reduce(state, action) {
		let category;
		let metricsKey;
		let appName;
		switch(action.actionType) {
			case Actions.RECEIVE_STEP_TOTAL_THROUGHPUT.actionType:
				category = "computation";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_STEP_BY_WORKER_TOTAL_THROUGHPUT.actionType:
				category = "computation-by-worker";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_SOURCE_SINK_TOTAL_THROUGHPUT.actionType:
				category = "start-to-end";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_TOTAL_THROUGHPUT.actionType:
				category = "start-to-end-by-worker";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_INGRESS_EGRESS_TOTAL_THROUGHPUT.actionType:
				category = "node-ingress-egress";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_TOTAL_THROUGHPUT.actionType:
				category = "node-ingress-egress-by-pipeline";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_PIPELINE_TOTAL_THROUGHPUT.actionType:
				category = "pipeline";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_PIPELINE_INGESTION_TOTAL_THROUGHPUT.actionType:
				category = "pipeline-ingestion";
				appName = action["total-throughput"].app_name;
				metricsKey = action["total-throughput"].pipeline_key;
				return this.filterTotalThroughputData(state, appName, category, metricsKey, action["total-throughput"]);
			case Actions.RECEIVE_STEP_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "computation";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_STEP_BY_WORKER_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "computation-by-worker";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_SOURCE_SINK_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "start-to-end";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_SOURCE_SINK_BY_WORKER_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "start-to-end-by-worker";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_INGRESS_EGRESS_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "node-ingress-egress";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_INGRESS_EGRESS_BY_PIPELINE_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "node-ingress-egress-by-pipeline";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_PIPELINE_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "pipeline";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			case Actions.RECEIVE_PIPELINE_INGESTION_INITIAL_TOTAL_THROUGHPUTS.actionType:
				category = "pipeline-ingestion";
				appName = action["initial-total-throughputs"].app_name;
				metricsKey = action["initial-total-throughputs"].pipeline_key;
				return this.filterInitialTotalThroughputsData(state, appName, category, metricsKey, action["initial-total-throughputs"]);
			default:
				return state;
		}
	}
}

const throughputsStore = new ThroughputsStore(Dispatcher);
export default throughputsStore;
